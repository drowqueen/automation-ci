include_recipe 'apt'

package 'nginx' do
  version node['nginx_version']
  action :install
end

# Use the default APT-provided service
service 'nginx' do
  action [:enable, :start]
end