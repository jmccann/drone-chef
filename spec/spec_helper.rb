require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
end
SimpleCov.start

$LOAD_PATH.unshift("#{File.dirname(__FILE__)}/../lib")
