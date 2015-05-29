#!/usr/bin/env ruby

# Runs as follows:
#
# ~$ ruby get-sip-identities.rb PEM_FILE


require "openssl"


module TLS

  # Extracts the SIP identities in a public certificate following
  # the mechanism in http://tools.ietf.org/html/rfc5922#section-7.1
  # and returns an array containing them.
  #
  # Arguments:
  # - _cert_: must be a public X.509 certificate in PEM format.
  #
  def self.get_sip_identities cert
    puts "DEBUG: following rules in RFC 5922 \"Domain Certificates in SIP\" section 7.1 \"Finding SIP Identities in a Certificate\""
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
      puts "DEBUG: certificate contains 'subjectAltName' extensions, 'CommonName' ignored"
      unless verify_subjectAltName_DNS
        subjectAltName_URI_sip_entries.each {|domain| sip_identities[domain] = true}
        puts "DEBUG: 'subjectAltName' entries of type \"URI:sip:\" found, 'subjectAltName' entries of type \"DNS\" ignored"
      else
        subjectAltName_DNS_entries.each {|domain| sip_identities[domain] = true}
        puts "DEBUG: 'subjectAltName' entries of type \"URI:sip:\" not found, using 'subjectAltName' entries of type \"DNS\""
      end

    else
      puts "DEBUG: no 'subjectAltName' extension found, using 'CommonName' value"
      cert.subject.to_a.each do |oid, value|
        if oid == "CN"
          sip_identities[value.downcase] = true
          break
        end
      end
    end

    return sip_identities
  end

end


unless (file = ARGV[0])
  $stderr.puts "ERROR: no file given as argument"
  exit false
end

unless ::File.file?(file) and ::File.readable?(file)
  $stderr.puts "ERROR: given file is not a readable file"
  exit false
end

begin
  cert = ::OpenSSL::X509::Certificate.new(::File.read(file))
rescue => e
  $stderr.puts "ERROR: cannot get a PEM certificate in the given file: #{e.message} (#{e.class})"
  exit false
end

sip_identities = TLS.get_sip_identities cert

puts
if sip_identities.any?
  puts "SIP identities found in the certificate:"
  puts
  sip_identities.each_key {|name| puts "  - #{name}"}
else
  puts "No SIP identities found in the certificate"
end
puts
