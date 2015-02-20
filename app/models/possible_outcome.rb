class PossibleOutcome
  include ActiveAttr::Model

  attribute :slot_bits
  attribute :brackets
  attribute :teams
  attribute :possible_games, type: Hash

  def self.generate_cached_opts
    games = Game.already_played.to_a + Game.not_played.to_a
    brackets = Bracket.includes(:picks).to_a
    teams = Team.all.each_with_object(Hash.new) {|team, acc| acc[team.id] = team}

    { games: games, brackets: brackets, teams: teams }
  end

  def self.generate_all_slot_bits
    already_played_games = Game.already_played.to_a
    to_play_games = Game.not_played.to_a

    already_played_winners_mask = 0

    already_played_games.each_with_index do |game, i|
      slot_index = already_played_games.size - i - 1
      if game.score_one < game.score_two
        already_played_winners_mask |= 1 << slot_index
      end
    end

    to_play_games_mask = 1
    to_play_games.size.times { |i| to_play_games_mask |= 1 << i }

    collected_slot_bits = []
    (0..to_play_games_mask).each do |to_play_bits|
      slot_bits = (already_played_winners_mask << to_play_games.size) | to_play_bits
      block_given? ? yield(slot_bits) : collected_slot_bits << slot_bits
    end

    block_given? ? nil : collected_slot_bits
  end

  def self.generate_outcome(slot_bits, opts = {})
    opts = generate_cached_opts if opts.empty?
    possible_outcome = new(slot_bits: slot_bits, brackets: opts[:brackets], teams: opts[:teams])

    opts[:games].each_with_index do |game, i|
      slot_index = opts[:games].size - i - 1
      team_one_winner = slot_bits & (1 << slot_index) == 0
      score_one, score_two = team_one_winner ?  [2, 1] : [1, 2]
      possible_outcome.create_possible_game game: game, score_one: score_one, score_two: score_two
    end

    possible_outcome
  end


  def create_possible_game(game_hash)
    possible_game = PossibleGame.new(game_hash.merge(possible_outcome: self))
    self.possible_games ||= {}
    self.possible_games[possible_game.game.id] = possible_game
  end

  def championship
    possible_game = self.possible_games.values.first
    possible_game = possible_game.next_game while possible_game.next_game.present?
    possible_game
  end

  def round_for(round_number, region = nil)
    case round_number
    when 5
      [championship.game_one, championship.game_two]
    when 6
      [championship]
    when 1
      sort_order = [1, 8, 5, 4, 6, 3, 7, 2]

      teams = region.present? ? Team.where(region: region) : Team
      team_ids = teams.where(seed: sort_order).select(:id).collect(&:id)
      game_ids = Game.where(team_one_id: team_ids).pluck(:id)

      games = []
      game_ids.each { |x| games << self.possible_games[x] }
      games.sort_by { |x| sort_order.index(x.first_team.seed) }
    else
      round_for(round_number - 1, region).collect(&:next_game).uniq
    end
  end

  def sorted_brackets
    result = self.brackets.collect do |bracket|
      points = bracket.picks.collect do |pick|
        possible_games[pick.game_id].points_for_pick(pick.team_id)
      end.sum
      [bracket, points]
    end

    result.sort_by(&:last).reverse
  end

  def update_brackets_best_possible
    sorted_brackets = self.sorted_brackets

    third_place_index = 2
    third_place_points = sorted_brackets[third_place_index][1]
    while sorted_brackets[third_place_index + 1][1] == third_place_points
      third_place_index += 1
    end

    sorted_brackets[0..third_place_index].each do |bracket, points|
      index = sorted_brackets.index { |_b, p| p == points }
      bracket.reload
      if bracket.best_possible > index
        bracket.best_possible = index
        bracket.save!
      end
    end
  end
end
