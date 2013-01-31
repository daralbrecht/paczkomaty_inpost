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
    machines = [{:name => "ALL992", :street => "Piłsudskiego", :buildingnumber => "2/4 ", :postcode => "95-070", :town => "Aleksandrów Łódzki",
            :latitude => "51.81284", :longitude => "19.31626", :paymentavailable => false, :operatinghours => "Paczkomat: 24/7",
            :locationdescription => "Przy markecie Polomarket", :paymentpointdescr => nil, :partnerid => 0, :paymenttype => 0, :type => "Pack Machine"}]
    prices = {"on_delivery_payment"=>"3.50", "on_delivery_percentage"=>"1.80", "on_delivery_limit"=>"5000.00", 
              "A"=>"6.99", "B"=>"8.99", "C"=>"11.99", "insurance"=>{"5000.00"=>"1.50", "10000.00"=>"2.50", "20000.00"=>"3.00"}}
    data_adapter.save_machine_list(machines,"1359396000")
    data_adapter.save_price_list(prices, "1359406810")
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


  context "inpost_machines_cache_is_valid?" do

    it "should return true if machines data is valid" do
      @api.params[:last_update] = '1359396000'
      @api.inpost_machines_cache_is_valid?.should equal(true)
    end

    it "should return false if machines data is out of date" do
      @api.params[:last_update] = '1000000000'
      @api.inpost_machines_cache_is_valid?.should equal(false)
    end
  end


  context "inpost_prices_cache_is_valid?" do

    it "should return true if prices data is valid" do
      @api.params[:last_update] = '1359406810'
      @api.inpost_prices_cache_is_valid?.should equal(true)
    end

    it "should return false if prices data is out of date" do
      @api.params[:last_update] = '1000000000'
      @api.inpost_prices_cache_is_valid?.should equal(false)
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


  context "inpost_get_pricelist" do

    it "should return price list" do
      file_path = 'spec/assets'
      PaczkomatyInpost::FileAdapter.any_instance.stub(:validate_path).and_return(true)
      data_adapter = PaczkomatyInpost::FileAdapter.new(file_path)
      request = PaczkomatyInpost::Request.new('test@testowy.pl','WqJevQy*X7')
      @api = PaczkomatyInpost::InpostAPI.new(request,data_adapter)

      prices = @api.inpost_get_pricelist

      prices['on_delivery_payment'].should == '3.50'
      prices['on_delivery_percentage'].should == '1.80'
      prices['on_delivery_limit'].should == '5000.00'
      prices['A'].should == '6.99'
      prices['B'].should == '8.99'
      prices['C'].should == '11.99'
      prices['insurance']['5000.00'].should == '1.50'
      prices['insurance']['10000.00'].should == '2.50'
      prices['insurance']['20000.00'].should == '3.00'
    end

    it "should return empty list if no data cached" do
      file_path = 'spec'
      PaczkomatyInpost::FileAdapter.any_instance.stub(:validate_path).and_return(true)
      data_adapter = PaczkomatyInpost::FileAdapter.new(file_path)
      request = PaczkomatyInpost::Request.new('test@testowy.pl','WqJevQy*X7')
      @api = PaczkomatyInpost::InpostAPI.new(request,data_adapter)

      prices = @api.inpost_get_pricelist

      prices.should == []
    end
  end


  context "inpost_get_towns" do

    before do
      PaczkomatyInpost::FileAdapter.any_instance.stub(:validate_path).and_return(true)
      @request = PaczkomatyInpost::Request.new('test@testowy.pl','WqJevQy*X7')
    end

    it "should return list of towns from cached machines" do
      data_adapter = PaczkomatyInpost::FileAdapter.new('spec/assets')
      @api = PaczkomatyInpost::InpostAPI.new(@request,data_adapter)

      towns = @api.inpost_get_towns

      towns.first.should == 'Aleksandrów Łódzki'
      towns.length.should == 186
    end

    it "should return empty list if cached machines missing" do
      data_adapter = PaczkomatyInpost::FileAdapter.new('spec')
      @api = PaczkomatyInpost::InpostAPI.new(@request,data_adapter)

      towns = @api.inpost_get_towns
      towns.should == []
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


  context 'inpost_find_customer' do

    before do
      data_adapter = PaczkomatyInpost::FileAdapter.new('spec/assets')
      request = PaczkomatyInpost::Request.new('test@testowy.pl','WqJevQy*X7')
      @api = PaczkomatyInpost::InpostAPI.new(request,data_adapter)
    end

    it "should return user preferences given registered email" do
      preferences = @api.inpost_find_customer('test01@paczkomaty.pl')

      preferences.should == {"preferedBoxMachineName"=>"KRA010", "alternativeBoxMachineName"=>"AND039"}
    end

    it "should return error message when user not found" do
      preferences = @api.inpost_find_customer('paczkomaty_test@example.com')

      preferences.should == {"error"=>{"OtherException"=>"Klient nie istnieje paczkomaty_test@example.com"}}
    end
  end


  context 'inpost_prepare_pack' do

    before do
      data_adapter = PaczkomatyInpost::FileAdapter.new('spec/assets')
      request = PaczkomatyInpost::Request.new('test@testowy.pl','WqJevQy*X7')
      @api = PaczkomatyInpost::InpostAPI.new(request,data_adapter)
    end

    it "should return pack ready to send if valid paramteres given" do
      sender = {:name => 'Sender', :surname => 'Tester', :email => 'test@testowy.pl', :phone_num => '578937487',
                :street => 'Test Street', :building_no => '12', :flat_no => nil, :town => 'Test City',
                :zip_code => '67-248', :province => 'pomorskie'}
      pack = @api.inpost_prepare_pack('pack_1', 'test01@paczkomaty.pl', '501892456', 'KRA010',
                            'B', '1.5', '10.99', 'testowa przesyłka', nil, sender)

      pack.valid?.should eq(true)
    end

    it "should throw error if invalid paramteres given" do
      sender = 'I am sender!'
      lambda { @api.inpost_prepare_pack('pack_1', 'test01@paczkomaty.pl', '501892456', 'KRA010',
                            'B', '1.5', '10.99', 'testowa przesyłka', nil, sender) }.should raise_error(RuntimeError)

    end

  end


  context 'inpost_send_packs' do

    before do
      sender = {:name => 'Sender', :surname => 'Tester', :email => 'test@testowy.pl', :phone_num => '578937487',
                :street => 'Test Street', :building_no => '12', :flat_no => nil, :town => 'Test City',
                :zip_code => '67-248', :province => 'pomorskie'}
      data_adapter = PaczkomatyInpost::FileAdapter.new('spec/assets')
      request = PaczkomatyInpost::Request.new('test@testowy.pl','WqJevQy*X7')
      @api = PaczkomatyInpost::InpostAPI.new(request,data_adapter)
      @pack_1 = @api.inpost_prepare_pack('pack_1', 'test01@paczkomaty.pl', '501892456', 'KRA010',
                            'B', '1.5', '10.99', 'testowa przesyłka', nil, sender)
      @pack_2 = @api.inpost_prepare_pack('pack_2', 'test04@paczkomaty.pl', '501892456', 'KRA010',
                            'B', '1.5', '10.99', 'testowa przesyłka', 'BBI233', sender)
      @pack_3 = @api.inpost_prepare_pack('pack_3', 'test03@paczkomaty.pl', '501892456', 'KRA010',
                            'B', '1.5', '10.99', 'testowa przesyłka')
      @invalid_pack = @api.inpost_prepare_pack('invalid_pack', 'test02@paczkomaty.pl', '501892456', 'KR0',
                            'D', '1.4', '11.99', 'testowa przesyłka', nil, sender)
    end

    it "should return array with given packcode for sended pack" do
      response = @api.inpost_send_packs(@pack_1)

      response.values_at("pack_1").should_not include(nil)
      response['pack_1'].values_at("packcode").should_not include(nil)
    end

    it "should return array with given packcodes for sended packs" do
      response = @api.inpost_send_packs([@pack_1, @pack_2, @pack_3])

      response.values_at("pack_1", "pack_2", "pack_3").should_not include(nil)
      response['pack_1'].values_at("packcode").should_not include(nil)
      response['pack_2'].values_at("packcode").should_not include(nil)
      response['pack_3'].values_at("packcode").should_not include(nil)
    end

    it "should return array with given packcodes and errors if any pack was invalid" do
      response = @api.inpost_send_packs([@pack_1, @invalid_pack])

      response.values_at("pack_1", "invalid_pack").should_not include(nil)
      response['pack_1'].values_at("packcode").should_not include(nil)
      response['invalid_pack'].values_at("error_key", "error_message").should_not include(nil)
    end

    it "should return error key and message if sending packs was unsuccessful" do
      @api.request.username = 'bad username'
      response = @api.inpost_send_packs(@pack_1)

      response['error'].should_not == nil
      response['pack_1'].should == nil
    end

  end


  context 'inpost_get_pack_status' do

    before do
      data_adapter = PaczkomatyInpost::FileAdapter.new('spec/assets')
      request = PaczkomatyInpost::Request.new('test@testowy.pl','WqJevQy*X7')
      @api = PaczkomatyInpost::InpostAPI.new(request,data_adapter)
      pack = @api.inpost_prepare_pack('pack_1', 'test01@paczkomaty.pl', '501892456', 'KRA010',
                            'B', '1.5', '10.99', 'testowa przesyłka')
      response = @api.inpost_send_packs(pack)
      @packcode = response['pack_1']['packcode']
    end

    it "should return status for pack assigned to given packcode" do
      pack_status = @api.inpost_get_pack_status(@packcode)

      pack_status['status'].should == 'Prepared'
    end

    it "should return error if invalid parameter given" do
      @packcode = 'invalid_packcode'
      pack_status = @api.inpost_get_pack_status(@packcode)

      pack_status['error'].should == {'PACK_NO_ERROR' => 'Błędny numer paczki'}
    end

  end

end
