require 'spec_helper'

describe PaczkomatyInpost do

  describe '::InpostAPI' do

    before do
      @api = PaczkomatyInpost::InpostAPI.new
    end

    describe 'check for environment options' do

      it "should return false if options aren't set" do
        @api.inpost_check_environment.should equal(false)
      end

      it "should return false and list of errors when verbose parameter set to true" do
        valid_options, errors = @api.inpost_check_environment(true)
        valid_options.should equal(false)
        errors.should == ['Paczkomaty API: path to proper data directory must be set in PaczkomatyInpost.options',
                          'Paczkomaty API: data_path in PaczkomatyInpost.options must be writable!',
                          'Paczkomaty API: username must be set in PaczkomatyInpost.options',
                          'Paczkomaty API: password must be set in PaczkomatyInpost.options']
      end

      it "should return true if options are set" do
        PaczkomatyInpost.options[:username] = "test@testowy.pl"
        PaczkomatyInpost.options[:password] = "WqJevQy*X7"
        PaczkomatyInpost.options[:data_path] = Dir::tmpdir

        @api.inpost_check_environment.should equal(true)
      end

      it "should return true and empty list of errors if options are set and verbose parameter set to true" do
        PaczkomatyInpost.options[:username] = "test@testowy.pl"
        PaczkomatyInpost.options[:password] = "WqJevQy*X7"
        PaczkomatyInpost.options[:data_path] = Dir::tmpdir

        valid_options, errors = @api.inpost_check_environment(true)
        valid_options.should equal(true)
        errors.should == []
      end
    end


    it "should get inpost params with valid data" do
      @api.inpost_get_params
      params = @api.params

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
