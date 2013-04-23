class Hash
  # https://github.com/rails/rails/blob/master/activesupport/lib/active_support/core_ext/hash/diff.rb
  def diff(other)
    dup.
      delete_if { |k, v| other[k] == v }.
      merge!(other.dup.delete_if { |k, v| has_key?(k) })
  end
end
