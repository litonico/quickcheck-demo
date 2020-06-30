require "minitest/autorun"

module QuickCheck
  class IntGenerator
    def gen(size)
      # NOTE(lito): This distribution won't give us a perfectly even coverage
      # of the integers, but for a demo it's fine.
      int = rand(size)
      sign = rand > 0.5 ? 1 : -1
      int * sign
    end
  end

  class IntMinimizer
    def move_toward_zero(next_example)
      if next_example == 0
        return 0
      elsif next_example < 0
        next_example += 1
      else
        next_example -= 1
      end
    end

    def shrink(known_counterexample, hypothesis)
      next_example = known_counterexample

      loop do
        if !hypothesis.call(next_example)
          known_counterexample = next_example

          next_example = move_toward_zero(next_example)
        else
          break
        end
      end

      known_counterexample
    end
  end

  class ArrayOfIntGenerator
    def gen(size)
      int_generator = IntGenerator.new
      # We want to start small and then search larger, in both the elements'
      # value and the length of the list.
      length = int_generator.gen(size).abs
      array = Array.new(length)
      array.map do |element|
        int_generator.gen(size)
      end
    end
  end

  class ArrayOfIntMinimizer
    def shrink(known_counterexample, hypothesis)
      shrink_elements_next = false

      int_minimizer = IntMinimizer.new

      next_example = known_counterexample

      loop do
        if !hypothesis.call(next_example)
          known_counterexample = next_example

          if known_counterexample == []
            return []
          end

          if shrink_elements_next
            shrink_elements_next = false

            next_example = known_counterexample.map do |element|
              int_minimizer.move_toward_zero(element)
            end
          else # shrink array length
            shrink_elements_next = true

            next_example = Array.new(known_counterexample)
            index_to_delete = rand(next_example.length)
            next_example.delete_at(index_to_delete)
          end
        else
          break
        end
      end

      return known_counterexample
    end
  end

  MAX_SIZE = 1024

  def self.falsify(type, &hypothesis)
    # TODO(lito): Float generators and minimizers
    if type == Integer
      example_generator = IntGenerator.new
      minimizer = IntMinimizer.new
    elsif type == Array
      # TODO(lito): Arrays of objects other than Ints
      example_generator = ArrayOfIntGenerator.new
      minimizer = ArrayOfIntMinimizer.new
    end

    counterexample = nil

    n_examples_tried = 0

    example_size = 1
    loop do
      if example_size > MAX_SIZE
        return nil
      end

      n_examples_tried += 1

      example = example_generator.gen(example_size)

      if !hypothesis.call(example)
        counterexample = example
        break
      end

      example_size *= 2
    end

    minimizer.shrink(counterexample, hypothesis)
  end
end

class TestQuickCheck < Minitest::Test
  def test_no_counterexample_for_correct_assertion
    def handwritten_abs(n)
      if n < 0
        n * -1
      elsif n > 0
        n
      else
        0
      end
    end

    def handwritten_sign(n)
      if n < 0
        -1
      elsif n > 0
        1
      else
        0
      end
    end

    abs_sign_counterexample = QuickCheck.falsify(Integer) do |n|
      handwritten_abs(n) * handwritten_sign(n) == n
    end
    assert_nil abs_sign_counterexample
  end

  def test_counterexample_found_for_incorrect_assertion
    def reverse ary
      ary.reverse
    end

    reverse_counterexample = QuickCheck.falsify(Array) do |array|
      reverse(array) == array
    end

    refute_nil reverse_counterexample
  end
end
