# Remove default declaration
gsub_file "lib/#{name}.rb", /register_instance_option :object_level do\n *true\n *end/m, ''
# Add root skeleton
inject_into_file "lib/#{name}.rb", after: "RailsAdmin::Config::Actions.register(self)" do
    pivot = "\n"
    pivot += "      register_instance_option :object_level do\n"
    pivot += "          false\n"
    pivot += "      end\n"
    pivot += "		# This ensures the action only shows up for Users\n"
    pivot += "		register_instance_option :visible? do\n"
    pivot += "		    # visible only if authorized and if the object has a defined method\n"
    pivot += "		    authorized? #&& bindings[:abstract_model].model == #{name.classify} && bindings[:abstract_model].model.column_names.include?('barcode')\n"
    pivot += "		end\n"
    pivot += "		# We want the action on members, not the Users collection\n"
    pivot += "		register_instance_option :member do\n"
    pivot += "		    false\n"
    pivot += "		end\n"
    pivot += "		\n"
    pivot += "		register_instance_option :collection do\n"
    pivot += "		    false\n"
    pivot += "		end\n"
    pivot += "		register_instance_option :root? do\n"
    pivot += "		    true\n"
    pivot += "		end\n"
    pivot += "		\n"
    pivot += "		register_instance_option :breadcrumb_parent do\n"
    pivot += "		    [nil]\n"
    pivot += "		end\n"
    pivot += "		\n"
    pivot += "		register_instance_option :link_icon do\n"
    pivot += "		    'icon-barcode'\n"
    pivot += "		end\n"
    pivot += "		# You may or may not want pjax for your action\n"
    pivot += "		register_instance_option :pjax? do\n"
    pivot += "		    true\n"
    pivot += "		end\n"
    pivot += "      	register_instance_option :http_methods do\n"
    pivot += "      	    [:get, :post]\n"
    pivot += "		end\n"
    pivot += "		# Adding the controller which is needed to compute calls from the ui\n"
    pivot += "		register_instance_option :controller do\n"
    pivot += "		    Proc.new do # This is needed becaus we sant that this code is re-evaluated each time is called\n"
    pivot += "		        # This could be useful to distinguish between ajax calls and restful calls\n"
    pivot += "		        # Avoid running code on pjax request, only the calls when the doument is ready and displayed are useful\n"
    pivot += "		        if request.xhr? && !request.headers['X-PJAX']\n"
    pivot += "		        end\n"
    pivot += "		    end\n"
    pivot += "		end\n"
    pivot += "\n"
end

initializer "load_root_action_for_#{name}.rb" do
    pivot = "RailsAdmin.config do |config|\n"
    pivot += "    config.actions do\n"
    pivot += "        #{name.gsub("rails_admin_", "")}\n"
    pivot += "    end\n"
    pivot += "end\n"
end

remove_file "app/views/rails_admin/main/#{name.gsub("rails_admin_", "")}.html.haml"

create_file "app/views/rails_admin/main/#{name.gsub("rails_admin_", "")}.html.erb" do
    "<%= breadcrumb %>\n<script>\n    $(document).on('ready pjax:success', function () {});\n</script>\n"
end
