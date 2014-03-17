require 'rbvmomi'
require 'i18n'
require 'vSphere/util/vim_helpers'
require 'vSphere/util/machine_helpers'

module VagrantPlugins
  module VSphere
    module Action
      class Snap
        include Util::VimHelpers
        include Util::MachineHelpers
        def initialize(app, env)
          @app = app
        end

        def call(env)
          machine = env[:machine]
          config = machine.provider_config          
          connection = env[:vSphere_connection]
          dc = get_datacenter connection, machine
          vm = dc.find_vm config.template_name
          raise Error::VSphereError, :message => I18n.t('errors.missing_template') if vm.nil?
          env[:ui].info " -- Connected"
          snap = find_snap_node(vm.snapshot.rootSnapshotList,  config.snapshot_name)
          raise Error::VSphereError, :message => "snapshot not found" if snap.nil?
          begin
            env[:ui].info I18n.t('vsphere.creating_cloned_vm')
            env[:ui].info " -- VM: #{config.template_name}, snapshot: #{config.snapshot_name}"
            snap.RevertToSnapshot_Task().wait_for_completion
            env[:ui].info " -- revert completed"
            #vm.PowerOnVM_Task.wait_for_completion
          rescue Exception => e
            puts e.message
            raise Errors::VSphereError, :message => e.message
          end

          #TODO: handle interrupted status in the environment, should the vm be destroyed?
          machine.id = vm.config.uuid
          # wait for SSH to be available 
          wait_for_ssh env
          
          env[:ui].info I18n.t('vsphere.vm_clone_success')          
            
          @app.call env
        end
      end
    end
  end
end
