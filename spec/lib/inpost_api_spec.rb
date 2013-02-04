# encoding: UTF-8
require 'spec_helper'

describe PaczkomatyInpost::InpostAPI do


  context "initialize" do

    before do
      @data_adapter = PaczkomatyInpost::FileAdapter.new(Dir::tmpdir)
    end

    it "should check if attributes given are valid and raise error if not" do
      lambda { PaczkomatyInpost::InpostAPI.new('',nil,'wrong data adapter object') }.should raise_error(RuntimeError)
      lambda { PaczkomatyInpost::InpostAPI.new('test@testowy.pl','WqJevQy*X7','wrong data adapter object') }.should raise_error(RuntimeError)
      lambda { PaczkomatyInpost::InpostAPI.new('','WqJevQy*X7',@data_adapter) }.should raise_error(RuntimeError)
    end

    it "should check if attributes given are valid and create object if true" do
      @api = PaczkomatyInpost::InpostAPI.new('test@testowy.pl','WqJevQy*X7',@data_adapter)

      @api.should be_kind_of(PaczkomatyInpost::InpostAPI)
    end
  end


  context "getting params by request" do

    before do
      data_adapter = PaczkomatyInpost::FileAdapter.new(Dir::tmpdir)
      @api = PaczkomatyInpost::InpostAPI.new('test@testowy.pl','WqJevQy*X7',data_adapter)
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
  end

  context "cache validator" do

    before do
      data_adapter = PaczkomatyInpost::FileAdapter.new(Dir::tmpdir)
      @api = PaczkomatyInpost::InpostAPI.new('test@testowy.pl','WqJevQy*X7',data_adapter)
      machines = [{:name => "ALL992", :street => "Piłsudskiego", :buildingnumber => "2/4 ", :postcode => "95-070", :town => "Aleksandrów Łódzki",
              :latitude => "51.81284", :longitude => "19.31626", :paymentavailable => false, :operatinghours => "Paczkomat: 24/7",
              :locationdescription => "Przy markecie Polomarket", :paymentpointdescr => nil, :partnerid => 0, :paymenttype => 0, :type => "Pack Machine"}]
      prices = {"on_delivery_payment"=>"3.50", "on_delivery_percentage"=>"1.80", "on_delivery_limit"=>"5000.00", 
                "A"=>"6.99", "B"=>"8.99", "C"=>"11.99", "insurance"=>{"5000.00"=>"1.50", "10000.00"=>"2.50", "20000.00"=>"3.00"}}
      data_adapter.save_machine_list(machines,"1359396000")
      data_adapter.save_price_list(prices, "1359406810")
    end

    context "for inpost machines" do

      it "should return true if machines data is valid" do
        @api.params[:last_update] = '1359396000'
        @api.inpost_machines_cache_is_valid?.should equal(true)
      end

      it "should return false if machines data is out of date" do
        @api.params[:last_update] = '1000000000'
        @api.inpost_machines_cache_is_valid?.should equal(false)
      end
    end

    context "for inpost prices" do

      it "should return true if prices data is valid" do
        @api.params[:last_update] = '1359406810'
        @api.inpost_prices_cache_is_valid?.should equal(true)
      end

      it "should return false if prices data is out of date" do
        @api.params[:last_update] = '1000000000'
        @api.inpost_prices_cache_is_valid?.should equal(false)
      end
    end
  end


  context "inpost_get_machine_list" do

    before do
      data_adapter = PaczkomatyInpost::FileAdapter.new('spec/assets')
      @api = PaczkomatyInpost::InpostAPI.new('test@testowy.pl','WqJevQy*X7',data_adapter)
    end


    it "should return list of all machines if no parameters given" do
      machines = @api.inpost_get_machine_list

      machines.length.should == 564
    end

    it "should return list of machines by town if given" do
      machines = @api.inpost_get_machine_list(:town => 'Gdynia')

      machines.length.should == 7
    end

    it "should be case insensitive" do
      machines = @api.inpost_get_machine_list(:town => 'Gdynia')
      lowercase_machines = @api.inpost_get_machine_list(:town => 'gdynia')

      machines.should == lowercase_machines
    end

    it "should return list of machines by paymentavailable if given" do
      machines = @api.inpost_get_machine_list(:paymentavailable => true)

      machines.length.should == 377
    end

    it "should return list of machines by town and paymentavailable if both given" do
      machines = @api.inpost_get_machine_list(:town => 'Gdynia', :paymentavailable => true)

      machines.length.should == 6
    end
  end


  context "inpost_get_pricelist" do

    it "should return price list" do
      data_adapter = PaczkomatyInpost::FileAdapter.new('spec/assets')
      @api = PaczkomatyInpost::InpostAPI.new('test@testowy.pl','WqJevQy*X7',data_adapter)

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
      data_adapter = PaczkomatyInpost::FileAdapter.new('spec')
      @api = PaczkomatyInpost::InpostAPI.new('test@testowy.pl','WqJevQy*X7',data_adapter)

      prices = @api.inpost_get_pricelist

      prices.should == []
    end
  end


  context "inpost_get_towns" do

    it "should return list of towns from cached machines" do
      data_adapter = PaczkomatyInpost::FileAdapter.new('spec/assets')
      @api = PaczkomatyInpost::InpostAPI.new('test@testowy.pl','WqJevQy*X7',data_adapter)

      towns = @api.inpost_get_towns

      towns.first.should == 'Aleksandrów Łódzki'
      towns.length.should == 186
    end

    it "should return empty list if cached machines missing" do
      data_adapter = PaczkomatyInpost::FileAdapter.new('spec')
      @api = PaczkomatyInpost::InpostAPI.new('test@testowy.pl','WqJevQy*X7',data_adapter)

      towns = @api.inpost_get_towns
      towns.should == []
    end
  end


  context "inpost_find_nearest_machines" do

    before do
      data_adapter = PaczkomatyInpost::FileAdapter.new('spec/assets')
      @api = PaczkomatyInpost::InpostAPI.new('test@testowy.pl','WqJevQy*X7',data_adapter)
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
      machines_without_payment_available = @api.inpost_find_nearest_machines('76-200',false)

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
      @api = PaczkomatyInpost::InpostAPI.new('test@testowy.pl','WqJevQy*X7',data_adapter)
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
      @api = PaczkomatyInpost::InpostAPI.new('test@testowy.pl','WqJevQy*X7',data_adapter)
    end

    it "should return pack ready to send if valid paramteres given" do
      sender = {:name => 'Sender', :surname => 'Tester', :email => 'test@testowy.pl', :phone_num => '578937487',
                :street => 'Test Street', :building_no => '12', :flat_no => nil, :town => 'Test City',
                :zip_code => '67-248', :province => 'pomorskie'}
      pack = @api.inpost_prepare_pack('pack_1', 'test01@paczkomaty.pl', '501892456', 'KRA010',
                            'B', '1.5', '10.99', :customer_ref => 'testowa przesyłka', :sender_address => sender)

      pack.valid?.should eq(true)
    end

    it "should throw error if invalid parameters given" do
      sender = 'I am sender!'
      lambda { @api.inpost_prepare_pack('pack_1', 'test01@paczkomaty.pl', '501892456', 'KRA010',
                            'B', '1.5', '10.99', :customer_ref => 'testowa przesyłka', :sender_address => sender) }.should raise_error(RuntimeError)
    end
  end


  context 'inpost_send_packs' do

    before do
      sender = {:name => 'Sender', :surname => 'Tester', :email => 'test@testowy.pl', :phone_num => '578937487',
                :street => 'Test Street', :building_no => '12', :flat_no => nil, :town => 'Test City',
                :zip_code => '67-248', :province => 'pomorskie'}
      data_adapter = PaczkomatyInpost::FileAdapter.new('spec/assets')
      @api = PaczkomatyInpost::InpostAPI.new('test@testowy.pl','WqJevQy*X7',data_adapter)
      @pack_1 = @api.inpost_prepare_pack('pack_1', 'test01@paczkomaty.pl', '501892456', 'KRA010',
                            'B', '1.5', '10.99', :customer_ref => 'testowa przesyłka', :sender_address => sender)
      @pack_2 = @api.inpost_prepare_pack('pack_2', 'test04@paczkomaty.pl', '501892456', 'KRA010',
                            'B', '1.5', '10.99', :customer_ref => 'testowa przesyłka', :alternative_box_machine_name => 'BBI233', :sender_address => sender)
      @pack_3 = @api.inpost_prepare_pack('pack_3', 'test03@paczkomaty.pl', '501892456', 'KRA010',
                            'B', '1.5', '10.99', :customer_ref => 'testowa przesyłka')
      @invalid_pack = @api.inpost_prepare_pack('invalid_pack', 'test02@paczkomaty.pl', '501892456', 'KR0',
                            'D', '1.4', '11.99', :customer_ref => 'testowa przesyłka', :sender_address => sender)
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


  context 'method' do

    before do
      data_adapter = PaczkomatyInpost::FileAdapter.new('spec/assets')
      @api = PaczkomatyInpost::InpostAPI.new('test@testowy.pl','WqJevQy*X7',data_adapter)
      pack = @api.inpost_prepare_pack('pack_1', 'test01@paczkomaty.pl', '501892456', 'KRA010','B', '1.5', '10.99')
      response = @api.inpost_send_packs(pack)
      @packcode = response['pack_1']['packcode']
    end


    context 'inpost_get_pack_status' do

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


    context 'inpost_cancel_pack' do

      # it "should return true if pack is canceled" do
        #TODO: Test it somehow - test accounts omits 'Created' in pack statuses and only 'Created' packs can be canceled
        # cancel_status = @api.inpost_cancel_pack(@packcode)

        # cancel_status.should eq(true)
      # end

      it "should return false if given packcode is empty" do
        @packcode = ''
        cancel_status = @api.inpost_cancel_pack(@packcode)

        cancel_status.should eq(false)
      end

      it "should return error if invalid parameter given" do
        @packcode = 'invalid_packcode'
        cancel_status = @api.inpost_cancel_pack(@packcode)

        cancel_status.should == 'No delivery pack with code: invalid_packcode'
      end
    end


    context 'inpost_change_packsize' do

      # it "should return true if packsize is changed" do
        #TODO: Test it somehow - test accounts omits 'Created' in pack statuses and only 'Created' packs can have packsize changed
        # packsize_status = @api.inpost_change_packsize(@packcode, 'B')

        # packsize_status.should eq(true)
      # end

      it "should return false if given data is incomplete" do
        packsize_status = @api.inpost_change_packsize(@packcode, '')

        packsize_status.should eq(false)
      end

      it "should return error if there were problems with changing packsize" do
        packsize_status = @api.inpost_change_packsize(@packcode,'B')

        packsize_status.should == '[51] Zmiana rozmiaru nie jest możliwa dla Paczki już opłaconej.'
      end
    end


    context 'inpost_pay_for_pack' do

      # it "should return true if pack status is changed to Prepared or CustomerDelivering" do
      # TODO: Test it somehow - test accounts have packs set automaticaly to Prepared
      #   pack_status = @api.inpost_pay_for_pack(@packcode)

      #   pack_status.should eq(true)
      # end

      it "should return false if given packcode is empty" do
        @packcode = ''
        pack_status = @api.inpost_pay_for_pack(@packcode)

        pack_status.should eq(false)
      end

      it "should return error if invalid parameter given" do
        @packcode = 'invalid_packcode'
        pack_status = @api.inpost_pay_for_pack(@packcode)

        pack_status.should == 'No delivery pack with code: invalid_packcode'
      end
    end


    context 'inpost_set_customer_ref' do

      it "should return true if customer ref was successful set" do
        ref_status = @api.inpost_set_customer_ref(@packcode,'custom ref')

        ref_status.should eq(true)
      end

      it "should return false if any given parameter is empty" do
        ref_status = @api.inpost_set_customer_ref(@packcode,'')

        ref_status.should eq(false)
      end

      it "should return error if invalid parameter given" do
        ref_status = @api.inpost_set_customer_ref('invalid','ref')

        ref_status.should == 'No delivery pack with code: invalid'
      end
    end


    context 'inpost_get_sticker' do

      it "should save sticker into pdf file at given path with packcode used as filename and return true" do
        sticker_status = @api.inpost_get_sticker(@packcode, :sticker_path => Dir::tmpdir)

        sticker_status.should eq(true)
        File.exist?(File.join(Dir::tmpdir, "sticker.#{@packcode}.pdf")).should eq(true)
      end

      it "should save sticker into pdf file at data_path if no path given" do
        sticker_status = @api.inpost_get_sticker(@packcode, :label_type => 'A6P')

        sticker_status.should eq(true)
        File.exist?(File.join(@api.data_adapter.data_path, "sticker.#{@packcode}.pdf")).should eq(true)

        File.delete(File.join(@api.data_adapter.data_path, "sticker.#{@packcode}.pdf"))
      end

      it "should return false if packode given is empty" do
        sticker_status = @api.inpost_get_sticker('')

        sticker_status.should eq(false)
      end

      it "should return false if packode given is nil" do
        sticker_status = @api.inpost_get_sticker(nil)

        sticker_status.should eq(false)
      end

      it "should return error message if invalid parameter given" do
        sticker_status = @api.inpost_get_sticker('invalid')

        sticker_status.should == 'Parcels with codes [invalid] not found'
      end
    end


    context 'inpost_get_stickers' do

      before do
        pack_2 = @api.inpost_prepare_pack('pack_2', 'test01@paczkomaty.pl', '501892456', 'KRA010','B', '1.5', '10.11')
        response = @api.inpost_send_packs(pack_2)
        packcode_2 = response['pack_2']['packcode']

        @packcodes = [@packcode, packcode_2]
      end

      it "should save stickers into pdf file at given path with packcodes used as filename and return true" do
        stickers_status = @api.inpost_get_stickers(@packcodes, :stickers_path => Dir::tmpdir)

        stickers_status.should eq(true)
        File.exist?(File.join(Dir::tmpdir, "stickers.#{@packcodes.join('.')}.pdf")).should eq(true)
      end

      it "should save stickers into pdf file at data_path if no path given" do
        stickers_status = @api.inpost_get_stickers(@packcodes, :label_type => 'A6P')

        stickers_status.should eq(true)
        File.exist?(File.join(@api.data_adapter.data_path, "stickers.#{@packcodes.join('.')}.pdf")).should eq(true)

        File.delete(File.join(@api.data_adapter.data_path, "stickers.#{@packcodes.join('.')}.pdf"))
      end

      it "should return false if packodes given is empty array" do
        stickers_status = @api.inpost_get_stickers([])

        stickers_status.should eq(false)
      end

      it "should return false if packodes given are nil" do
        stickers_status = @api.inpost_get_stickers(nil)

        stickers_status.should eq(false)
      end

      it "should return false if packodes given are empty string" do
        sticker_status = @api.inpost_get_stickers('')

        sticker_status.should eq(false)
      end

      it "should return error message if invalid parameter given" do
        sticker_status = @api.inpost_get_stickers('invalid parameter')

        sticker_status.should == 'Parcels with codes [invalid parameter] not found'
      end
    end

    context 'inpost_get_confirm_printout' do

      before do
        pack_2 = @api.inpost_prepare_pack('pack_2', 'test01@paczkomaty.pl', '501892456', 'KRA010','B', '1.5', '10.11')
        response = @api.inpost_send_packs(pack_2)
        packcode_2 = response['pack_2']['packcode']

        @packcodes = [@packcode, packcode_2]
      end

      it "should save printout into pdf file at given path with packcodes used as filename and return true" do
        printout_status = @api.inpost_get_confirm_printout(@packcodes, :printout_path => Dir::tmpdir)

        printout_status.should eq(true)
        File.exist?(File.join(Dir::tmpdir, "confirm_printout.#{@packcodes.join('.')}.pdf")).should eq(true)
      end

      it "should save stickers into pdf file at data_path if no path given" do
        printout_status = @api.inpost_get_confirm_printout(@packcodes)

        printout_status.should eq(true)
        File.exist?(File.join(@api.data_adapter.data_path, "confirm_printout.#{@packcodes.join('.')}.pdf")).should eq(true)
        File.delete(File.join(@api.data_adapter.data_path, "confirm_printout.#{@packcodes.join('.')}.pdf"))
      end

      it "should return false if packodes given is empty array" do
        printout_status = @api.inpost_get_confirm_printout([])

        printout_status.should eq(false)
      end

      it "should return false if packodes given are nil" do
        printout_status = @api.inpost_get_confirm_printout(nil)

        printout_status.should eq(false)
      end

      it "should return false if packodes given are empty string" do
        printout_status = @api.inpost_get_confirm_printout('')

        printout_status.should eq(false)
      end

      it "should return error message if invalid parameter given" do
        printout_status = @api.inpost_get_confirm_printout('invalid parameter')

        printout_status.should == '[129] Nie znaleziono paczek do potwierdzenia'
      end
    end

  end
end
