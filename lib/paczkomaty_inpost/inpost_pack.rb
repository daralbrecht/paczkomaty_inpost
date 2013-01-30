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
                          :alternative_box_machine_name, :pack_type, :insurance_amount, :on_delivery_amount, 
                          :customer_ref, :sender_address
    validate :sender_address_type


    def initialize(attributes = {})
      attributes.each do |name, value|
        send("#{name}=", value)
      end
    end

    def sender_address_type
      unless sender_address.kind_of?(Hash) && sender_address.has_key?(:name) && sender_address.has_key?(:surname) &&
              sender_address.has_key?(:email) && sender_address.has_key?(:phone_num) && sender_address.has_key?(:street) &&
              sender_address.has_key?(:building_no) && sender_address.has_key?(:flat_no) && sender_address.has_key?(:town) &&
              sender_address.has_key?(:zip_code) && sender_address.has_key?(:province)
        errors.add(:base, "Must be hash with sender address information")
      end
    end

    def persisted?
      false
    end

  end

end