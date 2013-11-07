require 'time'
require 'tzinfo'

module Fluent
  class TimeParserOutput < Output
    include Fluent::HandleTagNameMixin
    Fluent::Plugin.register_output('time_parser', self)

    config_param :key, :string, :default => 'time'
    config_param :time_zone, :string, :default => ''
    config_param :usec_digit, :integer, :default => 6
    config_param :parsed_time_tag, :string, :default => 'parsed_time'
    config_param :parsed_hour_tag, :string, :default => 'parsed_hour'
    config_param :parsed_date_tag, :string, :default => 'parsed_date'

    def configure(conf)
      super
      if (
          !remove_tag_prefix &&
          !remove_tag_suffix &&
          !add_tag_prefix    &&
          !add_tag_suffix
      )
        raise ConfigError, "out_extract_query_params: At least one of remove_tag_prefix/remove_tag_suffix/add_tag_prefix/add_tag_suffix is required to be set."
      end
    end

    def start
      super
    end

    def shutdown
      super
    end

    def emit(tag, es, chain)
      es.each {|time,record|
        t = tag.dup
        filter_record(t, time, record)
        Engine.emit(t, time, record)
      }
      chain.next
    end

    def filter_record(tag, time, record)
      begin
        record_time = DateTime.parse(record[key])

        if time_zone && time_zone != ""
          tz = TZInfo::Timezone.get(time_zone)

          period = tz.period_for_utc(record_time)
          rational_offset = period.utc_total_offset_rational

          record_time = tz.utc_to_local(record_time).new_offset(rational_offset) -
                        period.utc_total_offset_rational

        end
        date = record_time.to_date.to_s
        hour = record_time.hour.to_s

        record[parsed_time_tag] = record_time.iso8601(usec_digit)
        record[parsed_date_tag] = date if parsed_date_tag
        record[parsed_hour_tag] = hour if parsed_hour_tag

      rescue ArgumentError => error
        $log.warn("out_extract_query_params: #{error.message}")
      rescue TZInfo::InvalidTimezoneIdentifier
        $log.warn("Timezone Not Valid, please refer to http://tzinfo.rubyforge.org/doc/classes/TZInfo/Timezone.html for valid timezones")
      end
      super(tag, time, record)
    end
  end
end
