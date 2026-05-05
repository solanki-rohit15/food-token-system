# QR::Signer
#
# Generates and verifies Rails-signed QR payloads.
#
# WHY SIGNED?
#   Raw QR codes embedded internal IDs (order_item.id, item_code).
#   Anyone with a QR scanner could extract those IDs, guess others,
#   and probe the API. Instead we embed a signed, time-limited
#   message. The server verifies the signature before trusting anything.
#
# HOW IT WORKS:
#   - We use Rails.application.message_verifier(:qr_codes)
#     (backed by secret_key_base — only the server can sign/verify)
#   - The QR encodes ONLY a short public_token (random 16-char string)
#   - That public_token maps to the record in the DB
#   - The signed_payload (stored on the record) is the verifiable proof
#
# TWO QR TYPES:
#   :token      → top-level token QR (links to full order)
#   :order_item → per-item QR (links to individual meal)
#
# PUBLIC URL EMBEDDED IN QR:
#   /qr/<public_token>
#   → Hits PublicQrController#show
#   → Authenticated vendor: sees full redemption UI
#   → Anyone else: sees limited public info (name, category, date)

module QR
  class Signer
    VERIFIER_PURPOSE = :qr_codes
    EXPIRES_IN       = 18.hours  # generous window; tokens expire at 18:00 anyway

    # Signs a payload hash and returns the Rails message verifier signature.
    # Store this in the record's signed_payload column.
    def self.sign(payload)
      verifier.generate(payload.stringify_keys, expires_in: EXPIRES_IN)
    end

    # Verifies a signature and returns the original payload hash (string keys).
    # Returns nil if invalid, expired, or tampered.
    def self.verify(signature)
      verifier.verified(signature, purpose: nil)
    rescue ActiveSupport::MessageVerifier::InvalidSignature,
           ActiveSupport::MessageVerifier::InvalidMessage,
           ArgumentError
      nil
    end

    # Generates a short, unique public_token for URL embedding.
    # Opaque to the end user — contains no internal IDs or structure.
    def self.generate_public_token
      loop do
        token = SecureRandom.urlsafe_base64(12)  # 16 URL-safe chars
        # Collision check happens in the model callback
        return token
      end
    end

    private

    def self.verifier
      Rails.application.message_verifier(VERIFIER_PURPOSE)
    end
  end
end
