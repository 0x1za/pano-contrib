require "image_processing/vips"

# A photo from a phone, made safe to keep: re-encoded through libvips with
# every metadata block dropped (EXIF, including GPS; XMP; IPTC; ICC), and
# scaled to fit 1600 px, so a gate photo cannot carry the household's
# location or the phone's identity, and a 12 MB upload becomes a few
# hundred kB. Returns the processed file and its content type.
class PhotoUpload
  class Error < StandardError; end

  MAX_BYTES = 12.megabytes
  MAX_SIDE = 1600
  TYPES = %w[image/jpeg image/png image/webp image/heic image/heif].freeze

  Processed = Data.define(:file, :content_type, :filename)

  def self.call(upload)
    raise Error, "no photo" if upload.blank?
    raise Error, "photo is too large (over #{MAX_BYTES / 1.megabyte} MB)" if upload.size > MAX_BYTES
    # Sniff the bytes only: the declared type and the file name are the
    # uploader's claims, and a text file called photo.jpg is still text.
    type = Marcel::MimeType.for(Pathname.new(upload.tempfile.path))
    raise Error, "not a photo we can read (#{type})" unless TYPES.include?(type)

    file = ImageProcessing::Vips
      .source(upload.tempfile.path)
      .loader(autorot: true)
      .resize_to_limit(MAX_SIDE, MAX_SIDE)
      .saver(strip: true, quality: 82, interlace: true)
      .convert("jpg")
      .call
    Processed.new(file: file, content_type: "image/jpeg", filename: "photo.jpg")
  rescue Vips::Error => e
    raise Error, "could not read the photo: #{e.message.lines.first&.strip}"
  end
end
