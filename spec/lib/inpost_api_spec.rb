# encoding: UTF-8
require 'spec_helper'

describe PaczkomatyInpost::InpostAPI do


  context "check for environment options with invalid data" do

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


  context "check for environment options with valid data" do

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


  context "inpost_get_machine_list" do

    before do
      file_path = 'spec/assets'
      PaczkomatyInpost::FileAdapter.any_instance.stub(:validate_path).and_return(true)
      data_adapter = PaczkomatyInpost::FileAdapter.new(file_path)
      request = PaczkomatyInpost::Request.new('test@testowy.pl','WqJevQy*X7')
      @api = PaczkomatyInpost::InpostAPI.new(request,data_adapter)
    end


    it "should return list of all machines if no parameters given" do
      machines = @api.inpost_get_machine_list

      machines.length.should == 564
    end

    it "should return list of machines by town if given" do
      machines = @api.inpost_get_machine_list('Gdynia')

      machines.length.should == 7
    end

    it "should be case insensitive" do
      machines = @api.inpost_get_machine_list('Gdynia')
      lowercase_machines = @api.inpost_get_machine_list('gdynia')

      machines.should == lowercase_machines
    end

    it "should return list of machines by paymentavailable if given" do
      machines = @api.inpost_get_machine_list(nil,true)

      machines.length.should == 377
    end

    it "should return list of machines by town and paymentavailable if both given" do
      machines = @api.inpost_get_machine_list('Gdynia',true)

      machines.length.should == 6

      @api.inpost_find_nearest_machines('83-200', true)
    end
  end


  context "inpost_find_nearest_machines" do

    before do
      file_path = 'spec/assets'
      PaczkomatyInpost::FileAdapter.any_instance.stub(:validate_path).and_return(true)
      data_adapter = PaczkomatyInpost::FileAdapter.new(file_path)
      request = PaczkomatyInpost::Request.new('test@testowy.pl','WqJevQy*X7')
      @api = PaczkomatyInpost::InpostAPI.new(request,data_adapter)
    end

    it "should return list of 3 nearest machines if postcode given" do
      machines = @api.inpost_find_nearest_machines('83-200')

      machines.length.should == 3
    end

    it "should return list of 3 nearest machines sorted by distance" do
      machines = @api.inpost_find_nearest_machines('83-200')

      machines[0]['distance'].should < machines[1]['distance']
      machines[1]['distance'].should < machines[2]['distance']
    end

    it "should return list of 3 nearest machines by paymentavailable if given" do
      machines_with_payment_available = @api.inpost_find_nearest_machines('76-200',true)
      machines_without_payment_available = @api.inpost_find_nearest_machines('76-200',false,true)

      machines_with_payment_available.should_not == machines_without_payment_available
      machines_with_payment_available.map{|machine| machine['paymentavailable']}.uniq[0].should eq(true)
      machines_without_payment_available.map{|machine| machine['paymentavailable']}.uniq[0].should eq(false)
    end

    it "should return empty list if wrong postcode given" do
      machines = @api.inpost_find_nearest_machines('very bad postcode')

      machines.should == []
    end
  end

end
