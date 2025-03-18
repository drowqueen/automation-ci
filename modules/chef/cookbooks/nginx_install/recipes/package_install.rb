include_recipe 'apt'

package 'nginx' do
  version node['nginx_version']
  action :install
end

# Ensure the default service is running (uses /lib/systemd/system/nginx.service)
service 'nginx' do
  action [:enable, :start]
end