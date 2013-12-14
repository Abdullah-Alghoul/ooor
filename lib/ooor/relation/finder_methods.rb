require 'active_support/concern'

module Ooor
  module FinderMethods
    extend ActiveSupport::Concern

    module ClassMethods
      def find(*arguments)
        scope   = arguments.slice!(0)
        options = arguments.slice!(0) || {}
        case scope
          when :all   then find_single(nil, options)
          when :first then find_first_or_last(options)
          when :last  then find_first_or_last(options, "DESC")
          when :one   then find_one(options)
          else             find_single(scope, options)
        end
      end

      private
        def find_first_or_last(options, ordering = "ASC")
          options[:order] ||= "id #{ordering}"
          options[:limit] = 1
          domain = options[:domain] || []
          context = options[:context] || {}

          ids = rpc_execute('search', to_openerp_domain(domain), options[:offset] || 0, options[:limit],  options[:order], context.dup)
          find_single(ids.first, options)
        end

        def find_every(options)
          raise "NO MORE MAN!"
          domain = options[:domain] || []
          context = options[:context] || {}
          #prefix_options, domain = split_options(options[:params]) unless domain
          ids = rpc_execute('search', to_openerp_domain(domain), options[:offset] || 0, options[:limit] || false,  options[:order] || false, context.dup)
          !ids.empty? && ids[0].is_a?(Integer) && find_single(ids, options) || []
        end

        #actually finds many resources specified with scope = ids_array
        def find_single(scope, options)
          context = options[:context] || {}
          reload_fields_definition(false, context)
          fields = options[:fields] || options[:only] || fast_fields(options)
          
          if scope
            if scope.is_a? Array
              is_collection = true
            else
              scope = [scope]
              is_collection = false
            end
            scope.map! { |item| item_to_id(item, context) }.reject! {|item| !item}
            records = rpc_execute('read', scope, fields, context.dup)
            records.sort_by! {|r| scope.index(r["id"])} #TODO web client sorts already
          else
            is_collection = true
            records = object_service(:search_read, @openerp_model, 'search_read', { #TODO unless force xml_rpc
                fields: fields,
                offset: options[:offset] || 0,
                limit: options[:limit] || false,
                domain: options[:domain] || [],
                sort: options[:order] || false,
                context: context
              })["records"]
          end
          active_resources = []
          records.each { |record| active_resources << new(record, [], context, true)}
          if is_collection
            active_resources
          else
            active_resources[0]
          end
        end

        def item_to_id(item, context)
          if item.is_a?(String) && item.to_i == 0#triggers ir_model_data absolute reference lookup
            tab = item.split(".")
            domain = [['name', '=', tab[-1]]]
            domain << ['module', '=', tab[-2]] if tab[-2]
            ir_model_data = const_get('ir.model.data').find(:first, domain: domain, context: context)
            ir_model_data && ir_model_data.res_id && search([['id', '=', ir_model_data.res_id]], 0, false, false, context)[0]
          else
            item
          end
        end

    end
  end
end
