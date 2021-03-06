class CalculatePossibleOutcome
  include Sidekiq::Worker

  LIST_KEY = "possible_outcome_bits_list"

  def perform
    opts = PossibleOutcome.generate_cached_opts

    bits = pop_bits
    until bits.nil?

      if rand(5) == 0
        output = Benchmark.measure do
          PossibleOutcome.generate_outcome(bits.to_i, opts).update_brackets_best_possible
        end

        puts output
      else
        PossibleOutcome.generate_outcome(bits.to_i, opts).update_brackets_best_possible
      end

      bits = pop_bits
    end
  end

  def pop_bits
    bits = nil
    Sidekiq.redis do |redis|
      bits = redis.lpop(LIST_KEY)
    end
    bits
  end
end
