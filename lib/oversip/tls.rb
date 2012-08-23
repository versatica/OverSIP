module OverSIP

  module TLS

    extend ::OverSIP::Logger

    TLS_PEM_CHAIN_REGEXP = /-{5}BEGIN CERTIFICATE-{5}\n.*?-{5}END CERTIFICATE-{5}\n/m


    def self.log_id
      @log_id ||= "TLS"
    end


    def self.module_init
      configuration = ::OverSIP.configuration
      if configuration[:tls][:public_cert] and configuration[:tls][:private_cert]
        log_system_info "TLS enabled"
        ::OverSIP.tls_public_cert = configuration[:tls][:public_cert]
        ::OverSIP.tls_private_cert = configuration[:tls][:private_cert]
      else
        log_system_info "TLS disabled"
        return
      end

      if (ca_dir = configuration[:tls][:ca_dir])
        @store = ::OpenSSL::X509::Store.new
        num_certs_added = 0

        ::Dir.chdir ca_dir
        ca_files = ::Dir["*"]
        ca_files.select! { |ca_file| ::File.file?(ca_file) and ::File.readable?(ca_file) }
        ca_files.each do |ca_file|
          log_system_info "inspecting CA file '#{ca_file}'..."

          ca_file_content = ::File.read(ca_file)
          unless ca_file_content.valid_encoding?
            log_system_error "ignoring '#{ca_file}', invalid symbols found"
            next
          end

          pems = ca_file_content.scan(TLS_PEM_CHAIN_REGEXP).flatten
          num_pems = pems.size

          if num_pems == 0
            log_system_warn "'#{ca_file}': no public certificates found"
            next
          end
          log_system_info "'#{ca_file}': #{num_pems} public certificates found"

          now = ::Time.now
          certs = []
          pems.each do |pem|
            begin
              certs << ::OpenSSL::X509::Certificate.new(pem)
            rescue => e
              log_system_error "ignoring invalid X509 certificate: #{e.message} (#{e.class})"
              num_pems -= 1
            end
          end

          certs.reject! { |cert| cert.not_after < now }
          if certs.size != num_pems
            log_system_info "'#{ca_file}': ignoring #{num_pems - certs.size} expired certificates"
          end

          certs.each do |cert|
            begin
              @store.add_cert cert
              num_certs_added += 1
            # This occurs when a certificate is repeated.
            rescue ::OpenSSL::X509::StoreError => e
              log_system_warn "'#{ca_file}': ignoring certificate: #{e.message} (#{e.class})"
            end
          end
        end

        if num_certs_added == 0
          log_system_notice "zero public certificates found in '#{ca_dir}' directory, disabling TLS validation"
          @store = nil
        end
        log_system_info "#{num_certs_added} public certificates available for TLS validation"
      end

    end  # def self.module_init


    # Return an array with the result of the TLS certificate validation as follows:
    #   cert, validated, tls_error, tls_error_string
    # where:
    # - cert:      the ::OpenSSL::X509::Certificate instance of the first PEM provided by
    #              the peer, nil otherwise.
    # - validated: true if the given certificate(s) have been validated, false otherwise
    #              and nil if no certificate is provided by peer or no CA's were configured
    #              for TLS validation.
    # - tls_error: OpenSSL validation error code (Fixnum) in case of validation error.
    # - tls_error_string: OpenSSL validation error string in case of validation error.
    def self.validate pems
      return nil, nil, nil, "no CAs provided, validation disabled"  unless @store
      return nil, nil, nil, "no certificate provided by peer"  unless pems.any?

      pem = pems.pop
      intermediate_pems = pems

      begin
        cert = ::OpenSSL::X509::Certificate.new pem

        if intermediate_pems and intermediate_pems.any?
          intermediate_certs = []
          intermediate_pems.each do |pem|
            intermediate_certs << ::OpenSSL::X509::Certificate.new(pem)
          end
        else
          intermediate_certs = nil
        end

        if @store.verify cert, intermediate_certs
          return cert, true
        else
          return cert, false, @store.error, @store.error_string
        end

      rescue => e
        log_system_error "exception validating a certificate: #{e.class}: #{e.message}"
        return nil, false, e.class, e.message
      end
    end  # def self.validate


    def self.get_sip_identities cert
      return []  unless cert

      verify_subjectAltName_DNS = true
      verify_CN = true
      subjectAltName_URI_sip_entries = []
      subjectAltName_DNS_entries = []
      sip_identities = {}

      cert.extensions.each do |ext|
        next if ext.oid != "subjectAltName"
        verify_CN = false

        ext.value.split(/,\s+/).each do |name|
          if /^URI:sip:([^@]*)/i =~ name
            verify_subjectAltName_DNS = false
            subjectAltName_URI_sip_entries << $1.downcase
          elsif verify_subjectAltName_DNS && /^DNS:(.*)/i =~ name
            subjectAltName_DNS_entries << $1.downcase
          end
        end
      end

      unless verify_CN
        unless verify_subjectAltName_DNS
          subjectAltName_URI_sip_entries.each {|domain| sip_identities[domain] = true}
        else
          subjectAltName_DNS_entries.each {|domain| sip_identities[domain] = true}
        end

      else
        cert.subject.to_a.each do |oid, value|
          if oid == "CN"
            sip_identities[value.downcase] = true
            break
          end
        end
      end

      # Return an array with the SIP identities (domains) in the certificate.
      return sip_identities.keys
    end

  end

end
