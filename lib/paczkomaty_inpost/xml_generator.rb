# encoding: UTF-8
module PaczkomatyInpost

  class XmlGenerator

    attr_accessor :xml

    def initialize
      self.xml = Builder::XmlMarkup.new 
    end

    def generate_xml_for_data_packs(packs_data, auto_labels, self_send)
      xml.paczkomaty do
        xml.autoLabels auto_labels
        xml.selfSend self_send
        if packs_data.kind_of?(Array)
          packs_data.each {|pack| generate_xml_pack(pack)}
        else
          generate_xml_pack(packs_data)
        end
      end

      return xml
    end

    def generate_xml_pack(pack)
      xml.pack do
        xml.id pack.temp_id
        xml.adreseeEmail pack.adresee_email
        xml.senderEmail pack.sender_email
        xml.phoneNum pack.phone_num
        xml.boxMachineName pack.box_machine_name
        xml.alternativeBoxMachineName pack.alternative_box_machine_name unless pack.alternative_box_machine_name.nil?
        xml.packType pack.pack_type
        xml.customerDelivering(pack.customer_delivering.nil? ? false : pack.customer_delivering)
        xml.insuranceAmount pack.insurance_amount
        xml.onDeliveryAmount pack.on_delivery_amount
        xml.customerRef pack.customer_ref unless pack.customer_ref.nil?
        xml.senderBoxMachineName pack.sender_box_machine_name unless pack.sender_box_machine_name.nil?
        unless pack.sender_address.nil? || pack.sender_address.empty?
          xml.senderAddress do
            xml.name pack.sender_address[:name] unless pack.sender_address[:name]
            xml.surName pack.sender_address[:surname] unless pack.sender_address[:surname]
            xml.email pack.sender_address[:email] unless pack.sender_address[:email]
            xml.phoneNum pack.sender_address[:phone_num] unless pack.sender_address[:phone_num]
            xml.street pack.sender_address[:street] unless pack.sender_address[:street]
            xml.buildingNo pack.sender_address[:building_no] unless pack.sender_address[:building_no]
            xml.flatNo pack.sender_address[:flat_no] unless pack.sender_address[:flat_no]
            xml.town pack.sender_address[:town] unless pack.sender_address[:town]
            xml.zipCode pack.sender_address[:zip_code] unless pack.sender_address[:zip_code]
            xml.province pack.sender_address[:province] unless pack.sender_address[:province]
          end
        end
      end
    end

    def generate_xml_for_confirm_printout(packcodes,test_printout)
      xml.paczkomaty do
        xml.testprintout test_printout
        if packcodes.kind_of?(Array)
          packcodes.each {|code| xml.pack { xml.packcode code }}
        else
          xml.pack { xml.packcode packcodes }
        end
      end

      return xml
    end

  end
end