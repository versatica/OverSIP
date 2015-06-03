#!/usr/bin/env ruby

require "openssl"
require "socket"
require "readline"
require "term/ansicolor"


module OverSIP
  module Cert

    class Error < ::StandardError ; end

    extend Term::ANSIColor

    def self.create_cert

      begin
        puts
        puts bold(green("OverSIP TLS Certificate Generator"))

        puts
        puts bold("Certificate informational fields.")

        ca = OpenSSL::X509::Name.new

        cert_common_name = Readline.readline("- Common Name (eg, your name or your server's hostname): ").downcase.strip
        cert_common_name = nil if cert_common_name.empty?
        ca.add_entry "CN", cert_common_name if cert_common_name

        cert_country_code = Readline.readline("- Country Name (2 letter code): ").upcase.strip
        ca.add_entry "C", cert_country_code unless cert_country_code.empty?

        cert_state = Readline.readline("- State or Province Name (full name): ").strip
        ca.add_entry "ST", cert_state unless cert_state.empty?

        cert_locality = Readline.readline("- Locality Name (eg, city): ").strip
        ca.add_entry "L", cert_locality unless cert_locality.empty?

        cert_organization = Readline.readline("- Organization Name (eg, company): ").strip
        ca.add_entry "O", cert_organization unless cert_organization.empty?

        cert_organization_unit = Readline.readline("- Organizational Unit Name (eg, section): ").strip
        ca.add_entry "OU", cert_organization_unit unless cert_organization_unit.empty?

        cert_mail = Readline.readline("- Email: ").strip
        ca.add_entry "mail", cert_mail unless cert_mail.empty?

        puts
        puts bold("SubjectAltName SIP URI domains. ") + "For each given _domain_ an entry \"URI:sip:_domain_\" will be added to the SubjectAltName field."
        cert_sipuri_domains = Readline.readline("- SubjectAltName SIP URI domains (multiple values separated by space): ").downcase.strip.split
        cert_sipuri_domains = nil if cert_sipuri_domains.empty?

        puts
        puts bold("SubjectAltName DNS domains. ") + "For each given _domain_ an entry \"DNS:_domain_\" will be added to the SubjectAltName field."
        cert_dns_domains = Readline.readline("- SubjectAltName DNS domains (multiple values separated by space): ").downcase.strip.split
        cert_dns_domains = nil if cert_dns_domains.empty?

        puts
        puts bold("Signing data.")

        rsa_key_bits = Readline.readline("- RSA key bits (1024/2048/4096) [1024]: ").strip.to_i
        unless rsa_key_bits.zero?
          unless [1024, 2048, 4096].include? rsa_key_bits
            raise OverSIP::Cert::Error, "invalid number of bits (#{rsa_key_bits}) for RSA key"
          end
        else
          rsa_key_bits = 1024
        end

        key = OpenSSL::PKey::RSA.generate(rsa_key_bits)

        cert = OpenSSL::X509::Certificate.new
        cert.version = 2
        cert.subject = ca
        cert.issuer = ca
        cert.serial = Time.now.to_i
        cert.public_key = key.public_key

        years_to_expire = Readline.readline("- Expiration (in years from now) [1]: ").strip.to_i
        years_to_expire = 1 if years_to_expire.zero?
        cert.not_after = Time.now + (years_to_expire * 365 * 24 * 60 * 60)
        cert.not_before = Time.now - (24 * 60 * 60)

        factory = OpenSSL::X509::ExtensionFactory.new
        factory.subject_certificate = cert
        factory.issuer_certificate = cert

        subject_alt_name_fields = []

        cert_sipuri_domains.each do |sipuri_domain|
          subject_alt_name_fields.<< "URI:sip:#{sipuri_domain}"
        end if cert_sipuri_domains

        cert_dns_domains.each do |dns_domain|
          subject_alt_name_fields.<< "DNS:#{dns_domain}"
        end if cert_dns_domains

        extensions = {
          "basicConstraints" => "CA:TRUE",
          "subjectKeyIdentifier" => "hash"
        }
        if subject_alt_name_fields.any?
          extensions["subjectAltName"] = subject_alt_name_fields.join(",")
        end

        cert.extensions = extensions.map {|k,v| factory.create_ext(k,v) }

        cert.sign(key, OpenSSL::Digest::SHA1.new)

        puts
        puts bold("File name. ") + "For the given _name_ a public certificate _name_.crt and a private key _name_.key will be created. Also a file _name_.key.crt containing both the public certificate and the private key will be created."
        file_name = Readline.readline("- File name [#{cert_common_name}]: ").strip
        file_name = cert_common_name  if file_name.empty?
        unless file_name
          raise OverSIP::Cert::Error, "a file name must be set"
        end

        puts

        # Make two files:
        # - file_name.crt => public certificate.
        # - file_name.key => private key.
        {"key" => key, "crt" => cert}.each_pair do |ext, o|
          name = "#{file_name}.#{ext}"
          File.open(name, "w") {|f| f.write(o.to_pem) }
          File.chmod(0600, name) if ext == "key"

          case ext
          when "key"
            puts yellow(">> private key generated in file '#{bold("#{name}")}'")
          when "crt"
            puts yellow(">> public certificate generated in file '#{bold("#{name}")}'")
          end
        end

        # Make a single file containing both the public certificate and the private key.
        name = "#{file_name}.key.crt"
        File.open(name, "w") do |f|
          f.write(cert.to_pem)
          f.write(key.to_pem)
        end
        File.chmod(0600, name)
        puts yellow(">> public certificate + private key generated in file '#{bold("#{name}")}'")

      rescue ::Interrupt => e
        puts "\n\n" + red("Interrupted")
        exit

      rescue ::OverSIP::Cert::Error => e
        puts "\n" + bold(red("ERROR: #{e}"))
        exit 1
      end

    end # def create_cert

  end
end


OverSIP::Cert.create_cert

