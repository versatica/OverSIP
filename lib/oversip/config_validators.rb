require "openssl"


module OverSIP

  module Config

    module Validators

      extend ::OverSIP::Logger

      DOMAIN_REGEXP = /^(([0-9a-zA-Z\-_])+\.)*([0-9a-zA-Z\-_])+$/
      TLS_PEM_CHAIN_REGEXP = /-{5}BEGIN CERTIFICATE-{5}\n.*?-{5}END CERTIFICATE-{5}\n/m

      def boolean value
        value == true or value == false
      end

      def string value
        value.is_a? String
      end

      def fixnum value
        value.is_a? Fixnum
      end

      def port value
        fixnum(value) and value.between?(1,65536)
      end

      def ipv4 value
        return false  unless value.is_a? ::String
        ::OverSIP::Utils.ip_type(value) == :ipv4 and value != "0.0.0.0"
      end

      def ipv6 value
        return false  unless value.is_a? ::String
        ::OverSIP::Utils.ip_type(value) == :ipv6 and ::OverSIP::Utils.normalize_ipv6(value) != "::"
      end

      def ipv4_any value
        return false  unless value.is_a? ::String
        ::OverSIP::Utils.ip_type(value) == :ipv4
      end

      def ipv6_any value
        return false  unless value.is_a? ::String
        ::OverSIP::Utils.ip_type(value) == :ipv6
      end

      def domain value
        value =~ DOMAIN_REGEXP
      end

      def choices value, choices
        choices.include? value
      end

      def greater_than value, minimum
        value > minimum  rescue false
      end

      def greater_equal_than value, minimum
        value >= minimum  rescue false
      end

      def minor_than value, maximum
        value < maximum  rescue false
      end

      def minor_equal_than value, maximum
        value <= maximum  rescue false
      end

      def readable_file file
        ::File.file?(file) and ::File.readable?(file)
      end

      def readable_dir dir
        ::File.directory?(dir) and ::File.readable?(dir)
      end

      def tls_pem_chain file
        chain = ::File.read file
        pems = chain.scan(TLS_PEM_CHAIN_REGEXP).flatten
        pem_found = nil

        begin
          pems.each do |pem|
            ::OpenSSL::X509::Certificate.new pem
            pem_found = true
          end
        rescue => e
          log_system_error "#{e.class}: #{e.message}"
          return false
        end

        if pem_found
          return true
        else
          log_system_error "no valid X509 PEM found in the file"
          return false
        end
      end

      def tls_pem_private file
        pem = ::File.read file
        key_classes = [::OpenSSL::PKey::RSA, ::OpenSSL::PKey::DSA]

        begin
          key_class = key_classes.shift
          key_class.new pem
          return true
        rescue => e
          retry if key_classes.any?
          log_system_error e.message
        end

        return false
      end

    end # module Validators

  end # module Config

end
