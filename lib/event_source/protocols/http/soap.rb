# frozen_string_literal: true

require_relative "soap/types"
require_relative "soap/username_token_values"
require_relative "soap/security_header_configuration"
require_relative "soap/transport_security_configuration"
require_relative "soap/operations"

module EventSource
  module Protocols
    module Http
      # Namespace containing SOAP protocol operations and encoding over HTTP.
      module Soap
        XMLNS = {
          "soap" => "http://www.w3.org/2003/05/soap-envelope",
          "wsse" => "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd",
          "wsu" => "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd"
        }

        USERTOKEN_DIGEST_VALUES = {
          "plain" => "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordText",
          "digest" => "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordDigest"
        }

        USERNAME_TOKEN_BASE64_ENCODING_VALUE = "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-soap-message-security-1.0#Base64Binary"
      end
    end
  end
end