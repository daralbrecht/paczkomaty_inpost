require 'spec_helper'

PACZKOMATY_USERNAME = "test@testowy.pl"
PACZKOMATY_PASSWORD = "WqJevQy*X7"


describe PaczkomatyInpost do

  describe '::InpostRequest' do

    before do
      @request = PaczkomatyInpost::InpostRequest.new(PACZKOMATY_USERNAME, PACZKOMATY_PASSWORD)
    end


    it "should get inpost params with valid data" do
      @request.inpost_get_params
      params = @request.params

      params.should be_a_kind_of(Hash)
      params.keys.should =~ [:logo_url, :info_url, :rules_url, :register_url,  :last_update, :current_api_version]
      params.values.should_not include(nil)

      URI.parse(params[:logo_url]).should be_a_kind_of(URI::HTTP)
      URI.parse(params[:info_url]).should be_a_kind_of(URI::HTTP)
      URI.parse(params[:rules_url]).should be_a_kind_of(URI::HTTP)
      URI.parse(params[:register_url]).should be_a_kind_of(URI::HTTPS)

      params[:last_update].should match /\A\d+\z/
      params[:current_api_version].should eq(PaczkomatyInpost::VERSION)
    end

  end
end


