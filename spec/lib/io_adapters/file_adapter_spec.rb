# encoding: UTF-8
require 'spec_helper'

describe PaczkomatyInpost::FileAdapter do

    context 'given invalid data path' do
      
      before do
        @path = '/some/invalid/path'
      end

      it 'should raise Errno::ENOENT error after creation' do
        lambda { PaczkomatyInpost::FileAdapter.new(@path) }.should raise_error(Errno::ENOENT)
      end

    end


    context 'given non writable data path' do

      before do
        @path = '/'
      end

      it 'should raise Errno::EACCES error after creation' do
        lambda { PaczkomatyInpost::FileAdapter.new(@path) }.should raise_error(Errno::EACCES)
      end

    end


    context 'given valid data path' do

      before do
        @path = Dir::tmpdir
      end

      it 'shouldn\'t raise any errors after creation' do
        lambda { PaczkomatyInpost::FileAdapter.new(@path) }.should_not raise_error
      end

      before do
        @adapter = PaczkomatyInpost::FileAdapter.new(@path)
        data = [1359396000,{:name => "ALL992", :street => "Piłsudskiego", :buildingnumber => "2/4 ", :postcode => "95-070", :town => "Aleksandrów Łódzki",
                  :latitude => "51.81284", :longitude => "19.31626", :paymentavailable => false, :operatinghours => "Paczkomat: 24/7",
                  :locationdescription => "Przy markecie Polomarket", :paymentpointdescr => nil, :partnerid => 0, :paymenttype => 0, :type => "Pack Machine"}]
        @adapter.save_data(data)
      end

      it 'should save given data as json in machines.dat file' do
        content = File.read(Dir::tmpdir + '/machines.dat')

        content.should == "[1359396000,{\"name\":\"ALL992\",\"street\":\"Piłsudskiego\",\"buildingnumber\":\"2/4 \",\"postcode\":\"95-070\",\"town\":\"Aleksandrów Łódzki\",\"latitude\":\"51.81284\",\"longitude\":\"19.31626\",\"paymentavailable\":false,\"operatinghours\":\"Paczkomat: 24/7\",\"locationdescription\":\"Przy markecie Polomarket\",\"paymentpointdescr\":null,\"partnerid\":0,\"paymenttype\":0,\"type\":\"Pack Machine\"}]"
      end

      it 'should get data from file omitting last_update information' do
        content = @adapter.cached_data

        content.should == [{"name" => "ALL992", "street" => "Piłsudskiego", "buildingnumber" => "2/4 ", "postcode" => "95-070", "town" => "Aleksandrów Łódzki",
                  "latitude" => "51.81284", "longitude" => "19.31626", "paymentavailable" => false, "operatinghours" => "Paczkomat: 24/7",
                  "locationdescription" => "Przy markecie Polomarket", "paymentpointdescr" => nil, "partnerid" => 0, "paymenttype" => 0, "type" => "Pack Machine"}]
      end

      it 'should get last_update information from machines.dat' do
        content = @adapter.last_update

        content.should == 1359396000
      end

    end

end
