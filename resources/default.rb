#
# Cookbook Name:: opsview_client
# Resource:: default
#
# Author:: Gene Wood <gene_wood@cementhorizon.com>

actions :create
default_action :create

attribute :host_templates, :kind_of => Array, :default => []
attribute :host_group, :kind_of => String, :name_attribute => true
attribute :check_period, :kind_of => String, :default => "24x7"
attribute :server_url, :kind_of => String
attribute :username, :kind_of => String, :default => "admin"
attribute :password, :kind_of => String, :default => "initial"
attribute :ipaddress, :kind_of => String, :default => node[:ipaddress]
attribute :host_attributes, :kind_of => Array, :default => []
attribute :data, :kind_of => Hash
