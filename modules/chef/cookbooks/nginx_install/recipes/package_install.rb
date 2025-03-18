include_recipe 'apt'

Chef::Log.info("Starting Nginx package installation")

package 'nginx' do
  version node['nginx_version']
  action :install
  notifies :run, 'execute[check-nginx-install]', :immediately
end

execute 'check-nginx-install' do
  command 'dpkg -l | grep nginx || { echo "Nginx package installation failed"; exit 1; }'
  action :nothing
end

service 'nginx' do
  action [:enable, :start]
end

Chef::Log.info("Nginx package installation completed")