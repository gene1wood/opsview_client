# set[:opsview_client][:host_templates] = ["Application - Apache HTTP", "Database - MySQL"]
# set[:opsview_client][:host_group] = "Monitoring Servers"
# set[:opsview_client][:server_url] = "http://opsview.example.com:3000/rest"
# set[:opsview_client][:username] = "admin"
# set[:opsview_client][:password] = "initial"
default["opsview_client"]["check_period"] = "24x7"
