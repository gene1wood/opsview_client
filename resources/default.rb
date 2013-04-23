#
# Cookbook Name:: opsview_client
# Resource:: default
#
# Author:: Gene Wood <gene_wood@cementhorizon.com>

actions :create
default_action :create

attribute :host_templates, :kind_of => Array, :default => node[:opsview_client][:host_templates]
attribute :host_group, :kind_of => Hash, :default => node[:opsview_client][:host_group]
attribute :check_period, :kind_of => Hash, :default => node[:opsview_client][:check_period]
attribute :server_url, :kind_of => String, :default => node[:opsview_client][:server_url]
attribute :username, :kind_of => String, :default => node[:opsview_client][:username]
attribute :password, :kind_of => String, :default => node[:opsview_client][:password]
attribute :ipaddress, :kind_of => String, :default => node[:ipaddress]
attribute :data, :kind_of => Hash
