require 'open-uri'
module SimpleApi
  module RuleDefs
    class ExtendedRuleItem
      attr_accessor :definition, :config, :filter, :current_rule
      def initialize(rule, flt)
        self.filter = flt
        self.current_rule = rule
        self.definition = SimpleApi::RuleDefs::TYPES[flt]
        self.config = JSON.load(rule.filters[flt]) rescue rule.filters[flt]
        self.config ||= 'any'
      end

      def check(param)
        if config.is_a?(::String)
          return true if config == 'empty' && param.data[filter].blank?
          return true if config == 'non-empty' && param.data[filter].present?
          return true if config == 'any'
        end
        false
      end

      def load_list(list)
        fapi_prefix = CONFIG["fapi_prefix"]
        # refactor for sentimeta
        uri = [fapi_prefix].tap do |bb|
          bb << current_rule.sphere
          bb << list
          bb << filter
        end.join('/')
        parm = URI.encode('p={"limit_values": "10000"}')
        data = JSON.load(URI.parse([uri, parm].join('?')).open.read) #rescue {} #TODO fix error handling
        return {meta: false, data: [{filter => nil}]} if data.empty? || data["values"].blank?
        {meta: true, data: data["values"].map{|hsh| hsh["name"] }.map{|i| {filter => i} } + ('any' == config ? [{filter => nil}] : [])}
      end

      def load_from_master
        if definition["fetch_list"].present?
          return load_list(definition["fetch_list"])
        else
          return {meta: false}
        end
      end

      def fetch_list
        return load_from_master if %w(any non-empty).include?(config)
        {meta: false}
      end

    end
  end
end
