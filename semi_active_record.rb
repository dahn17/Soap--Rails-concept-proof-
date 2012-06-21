module Functions
  module Soap
    class SemiActiveRecord < ActiveRecord::Base
      set_table_name 'dummy'

      def initialize(*args)
        super(args[0])
        after_find
        after_initialize
      end

      def save(*args)
        # Asignamos al objeto los valores que se han mandado desde el formulario
        instance_variables.each do |x|
          attr_name = x[1..-1]
          eval("self.#{attr_name} = @@new_obj_data[attr_name]") if self.id.blank? and not [ 'changed_attributes', 'attributes', 'new_record', 'attributes_cache', 'errors' ].include? attr_name
        end
        # Ejecutamos los callbacks
        before_validation
        if self.valid?
          after_validation
          before_save
          if self.new_record?
            before_create
          else
            before_update
          end
          # Construimos un hash de parámetros y se lo pasamos al método definido en "save_method"
          obj_data = Hash.new
          self.class.attr_names.keys.each do |a|
            a_val = eval("self.#{a}")
            a_val = a_val.to_s if a_val.is_a? Integer
            obj_data[a.to_s] = a_val
          end
          result = self.class.save_method(obj_data)
          if self.new_record?
            after_create
          else
            after_update
          end
          after_save
        end
        result
      end

      def destroy
        before_destroy
        result = self.class.destroy_method self.id
        after_destroy
        result
      end

      protected

        def self.new(*args)
          @@new_obj_data = args[0]
          attr_names
          super
        end

        def self.find(*args)
          # Si buscamos un sólo elemento, pasamos su ID en el parámetro "conditions"
          if [ :all, 'all' ].include? args[0]
            args[1][:conditions] = modify_args(args[1][:conditions])
            find_args = args[1]
          else
            find_args = { :conditions => modify_args("id = '#{args[0].to_i}'") }
          end
          # Si se ha definido algún orden, hacemos que su contenido corresponda con la nueva nomenclatura de campos
          if find_args.include? :order
            self.attr_names.each do |k,v|
              find_args[:order] = find_args[:order].gsub("#{k} ", "#{v} ")
            end
          end
          # Llamamos al método de búsqueda
          result = self.find_method(find_args)
          result_content = (result.is_a? SOAP::Mapping::Object) ? result.__xmlele : result
          result = [ result ] unless result.is_a? Array
          new_result = Array.new
          # Iteramos el resultado
          unless result_content.blank?
            result.each do |obj|
              attr_names_and_values = Hash.new
              self.attr_names.each do |k,v|
                attr_names_and_values[k] = obj[v.to_s] unless k == :id
              end
              new_obj = self.new attr_names_and_values
              new_obj.id = obj[self.attr_names[:id].to_s].to_i
              new_result.push new_obj
            end
          end
          # Si buscamos sólo un elemento, lo devolvemos fuera del array
          new_result = new_result[0] unless [ :all, 'all' ].include? args[0]
          new_result
        end

        def self.count(*args)
          conditions = modify_args(args[0][:conditions]) unless args[0][:conditions].blank?
          conditions ||= nil
          result = self.count_method conditions
          result = 0 unless result.is_a? Integer
          result
        end

        def self.modify_args(args)
          # Si los argumentos vienen en formato Hash, lo convertimos a cadena
          if args.is_a? Hash
            new_args = String.new
            args.each do |k,v|
              new_args += "#{k} = '#{v}' AND "
            end
            args = new_args[0..-6]
          end
          args = " #{args}"
          # Sustituimos los nombres de campo
          self.attr_names.each do |k,v|
            args.gsub! " #{k.to_s} ", " #{v.to_s} "
          end
          args[1..-1]
        end

        # Callbacks
        def after_find() end
        def after_initialize() end
        def before_validation() end
        def after_validation() end
        def before_save() end
        def before_create() end
        def before_update() end
        def after_create() end
        def after_update() end
        def after_save() end
        def before_destroy() end
        def after_destroy() end

      private

        def self.attr_names(names)
          # Si los atributos proporcionados no existen todavía en el objeto, los agregamos
          @attrs = false unless @attrs
          unless @attrs
            names.each do |k,v|
              attr_accessor k.to_sym unless [ :id, 'id' ].include? k
            end
            @attrs = true
          end
          names[:id] = :id unless names.include? :id
          names
        end
    end
  end
end