require 'rspec'
require './bart'

RSpec.describe BartEstimates do
  let(:estimator) { BartEstimates.new('MONT') }

  it 'provides a text result' do
    estimator.run
    p estimator.text_results
  end
end
