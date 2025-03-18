install_method = node['install_method']

case install_method
when 'package'
  Chef::Log.info("Including package_install recipe")
  include_recipe 'nginx_install::package_install'
when 'source'
  Chef::Log.info("Including source_install recipe")
  include_recipe 'nginx_install::source_install'
else
  raise "Invalid install_method: #{install_method}. Must be 'package' or 'source'"
end

template '/etc/nginx/nginx.conf' do
  source 'nginx.conf.erb'
  owner 'root'
  group 'root'
  mode '0644'
  variables(
    worker_processes: node['worker_processes'],
    listen_port: node['listen_port'],
    server_name: node['server_name'],
    install_method: node['install_method']
  )
  notifies :restart, 'service[nginx]', :delayed
end

service 'nginx' do
  action :nothing  # Managed by specific recipes
end