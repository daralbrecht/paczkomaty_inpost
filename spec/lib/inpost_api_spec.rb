# encoding: UTF-8
require 'spec_helper'

describe PaczkomatyInpost::InpostAPI do


  context 'check for environment options with invalid data' do

    before do
      data_adapter = 'wrong data adapter object'
      request = 'wrong request object'
      @api = PaczkomatyInpost::InpostAPI.new(request,data_adapter)
    end

    it "should return false" do
      @api.inpost_check_environment.should equal(false)
    end

    it "should return false and list of errors" do
      valid_options, errors = @api.inpost_check_environment(true)
      valid_options.should equal(false)
      errors.should == ['Paczkomaty API: użyty data adapter jest niekompatybilny z API',
                        'Paczkomaty API: nazwa użytkownika musi być zapisana w PaczkomatyInpost::Request',
                        'Paczkomaty API: hasło musi być zapisane w PaczkomatyInpost::Request']
    end
  end


  context 'check for environment options with valid data' do

    before do
      file_path = Dir::tmpdir
      data_adapter = PaczkomatyInpost::FileAdapter.new(file_path)
      request = PaczkomatyInpost::Request.new('test@testowy.pl','WqJevQy*X7')
      @api = PaczkomatyInpost::InpostAPI.new(request,data_adapter)
    end

    it "should return true" do
      @api.inpost_check_environment.should equal(true)
    end

    it "should return true and empty list of errors" do
      valid_options, errors = @api.inpost_check_environment(true)
      valid_options.should equal(true)
      errors.should == []
    end
  end


  before do
    file_path = Dir::tmpdir
    data_adapter = PaczkomatyInpost::FileAdapter.new(file_path)
    request = PaczkomatyInpost::Request.new('test@testowy.pl','WqJevQy*X7')
    @api = PaczkomatyInpost::InpostAPI.new(request,data_adapter)
    data = [1359396000,{:name => "ALL992", :street => "Piłsudskiego", :buildingnumber => "2/4 ", :postcode => "95-070", :town => "Aleksandrów Łódzki",
            :latitude => "51.81284", :longitude => "19.31626", :paymentavailable => false, :operatinghours => "Paczkomat: 24/7",
            :locationdescription => "Przy markecie Polomarket", :paymentpointdescr => nil, :partnerid => 0, :paymenttype => 0, :type => "Pack Machine"}]
    data_adapter.save_data(data)
  end


  it "should get inpost params with valid data" do
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

  context "check for valid cache data" do

    it "should return true if data is valid" do
      @api.params[:last_update] = 1359396000
      @api.inpost_cache_is_valid?.should equal(true)
    end

    it "should return false if data is out of date" do
      @api.params[:last_update] = 1000000000
      @api.inpost_cache_is_valid?.should equal(false)
    end
  end

end
