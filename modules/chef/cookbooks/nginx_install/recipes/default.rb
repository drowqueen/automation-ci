install_method = node['install_method']

case install_method
when 'package'
  include_recipe 'nginx_install::package_install'
when 'source'
  include_recipe 'nginx_install::source_install'
else
  raise "Invalid install_method: #{install_method}. Must be 'package' or 'source'"
end

# Apply custom configuration
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
  notifies :restart, 'service[nginx]', :delayed  # Restart only after config is applied
end

service 'nginx' do
  action :nothing  # Managed by package/source recipes and config template
end