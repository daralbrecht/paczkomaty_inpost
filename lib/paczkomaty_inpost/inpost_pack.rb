# encoding: UTF-8
require 'active_model'

module PaczkomatyInpost

  class InpostPack
    include ActiveModel::Validations
    include ActiveModel::Conversion
    extend ActiveModel::Naming

    attr_accessor :temp_id, :adresee_email, :sender_email, :phone_num, :box_machine_name,
                  :alternative_box_machine_name, :customer_delivering, :sender_box_machine_name,
                  :pack_type, :insurance_amount, :on_delivery_amount, :customer_ref, :sender_address

    validates_presence_of :temp_id, :adresee_email, :sender_email, :phone_num, :box_machine_name,
                          :pack_type, :insurance_amount, :on_delivery_amount
    validate :sender_address_type, :unless => lambda{ sender_address.nil? }


    def initialize(attributes = {})
      attributes.each do |name, value|
        send("#{name}=", value)
      end

      missing_attributes = [:alternative_box_machine_name, :customer_delivering, :sender_box_machine_name, :customer_ref, :sender_address] - attributes.keys

      missing_attributes.each do |name|
        send("#{name}=", nil)
      end
    end

    def sender_address_type
      unless sender_address.kind_of?(Hash)
        errors.add(:base, "Must be hash with sender address information")
      end
    end

    def persisted?
      false
    end

  end

end