include_recipe 'apt'

package 'nginx' do
  version node['nginx_version']
  action :install
end

service 'nginx' do
  action [:enable, :start]  # Explicitly ensure it’s running
end