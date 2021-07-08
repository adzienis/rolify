require 'rolify/adapters/base'
require 'rolify/configure'
require 'rolify/dynamic'
require 'rolify/railtie' if defined?(Rails)
require 'rolify/resource'
require 'rolify/role'

module Rolify
  extend Configure

  attr_accessor :role_cname, :adapter, :resource_adapter, :role_join_table_name, :role_table_name, :strict_rolify
  @@resource_types = []

  def rolify(options = {})
    include Role
    extend Dynamic if Rolify.dynamic_shortcuts

    options.reverse_merge!({:role_cname => 'Role'})
    self.role_cname = options[:role_cname]
    self.role_table_name = self.role_cname.tableize.gsub(/\//, "_")




    # Option to support has_many :through
    rolify_options = {}
    has_many_through_table = options.delete(:has_many_through)
    if has_many_through_table
      self.role_join_table_name = has_many_through_table
      rolify_options[:through] = self.role_join_table_name
      has_many :roles, **rolify_options
      role = self.role_cname.to_s.classify.constantize
      role.singleton_class.send(:attr_accessor, :role_join_class)
      role.role_join_class = self.name.constantize.reflect_on_association(has_many_through_table).klass
    else
      default_join_table = "#{self.to_s.tableize.gsub(/\//, "_")}_#{self.role_table_name}"
      options.reverse_merge!({:role_join_table_name => default_join_table})
      self.role_join_table_name = options[:role_join_table_name]
      rolify_options.merge!({ :join_table => self.role_join_table_name }) if Rolify.orm == "active_record"

      has_and_belongs_to_many :roles, **rolify_options
    end

    self.adapter = Rolify::Adapter::Base.create("role_adapter", self.role_cname, self.name)

    #self.define_method(:role_join_class) do
    #  role_join_table_name.to_s.classify.constantize
    #end

    #use strict roles
    self.strict_rolify = true if options[:strict]
  end

  def adapter
    return self.superclass.adapter unless self.instance_variable_defined? '@adapter'
    @adapter
  end

  def resourcify(association_name = :roles, options = {})
    include Resource

    options.reverse_merge!({ :role_cname => 'Role', :dependent => :destroy })
    resourcify_options = { :class_name => options[:role_cname].camelize, :as => :resource, :dependent => options[:dependent] }
    self.role_cname = options[:role_cname]
    self.role_table_name = self.role_cname.tableize.gsub(/\//, "_")

    has_many association_name, **resourcify_options

    self.resource_adapter = Rolify::Adapter::Base.create("resource_adapter", self.role_cname, self.name)
    @@resource_types << self.name
  end

  def resource_adapter
    return self.superclass.resource_adapter unless self.instance_variable_defined? '@resource_adapter'
    @resource_adapter
  end

  def scopify
    require "rolify/adapters/#{Rolify.orm}/scopes.rb"
    extend Rolify::Adapter::Scopes
  end

  def role_class
    return self.superclass.role_class unless self.instance_variable_defined? '@role_cname'
    self.role_cname.constantize
  end

  def self.resource_types
    @@resource_types
  end

end
