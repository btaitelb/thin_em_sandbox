# This file is used by Rack-based servers to start the application.

require ::File.expand_path('../config/environment',  __FILE__)
use Rack::FiberPool, :size => 200
run Vanilla::Application