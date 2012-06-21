module Functions
  module Soap
    class Connect

      def self.create_connection(method, class_name)
        SOAP::WSDLDriverFactory.new(SOAP_CONNECTION[RAILS_ENV][class_name]).create_rpc_driver
      end

      private

        def self.method_missing(method, *args)
          self.new.method_missing(method, args)
        end

        def method_missing(method, *args)
          begin
            # Limpiamos la lista de parámetros
            args = args[0] if args[0].is_a? Array and args[1].blank?
            # Definimos la clase
            if args.last.is_a? Hash and args.last.include? :class_name
              class_name = args.last[:class_name]
              args.delete args.last
            else
              class_name = self.class.to_s
            end
            # Montamos la cadena de parámetros
            args = args.map{ |x| x = (x.is_a? String) ? "'#{x.gsub("'", '"')}', " : "#{x.inspect}, "; x }.join[0..-3].gsub("''", 'nil')
            # Abrimos la conexión y obtenemos los datos
            eval "Functions::Soap::Connect.create_connection(method, class_name).#{method} #{args}"
          rescue Exception => e
            Rails.logger.error e
            Array.new
          end
        end
    end
  end
end