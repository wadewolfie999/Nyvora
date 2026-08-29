# frozen_string_literal: true

require "digest"
require "erb"
require "fileutils"
require "yaml"

module NodeControl
  class NCM3RenderContext
    def initialize(configuration)
      @configuration = configuration
    end

    def get_binding
      binding
    end

    def control_host
      @configuration.endpoint("control")
    end

    def auth_host
      @configuration.endpoint("auth")
    end

    def bus_host
      @configuration.endpoint("bus")
    end

    def tunnel_host
      @configuration.endpoint("tunnel")
    end

    def vps_frps_transport
      @configuration.port("vps-node", "loopback_tcp", "frps_transport")
    end

    def vps_frps_vhost
      @configuration.port("vps-node", "loopback_tcp", "frps_vhost_http")
    end

    def asus_controller
      @configuration.port("asus-node", "loopback_tcp", "controller")
    end

    def asus_authentik
      @configuration.port("asus-node", "loopback_tcp", "authentik_http")
    end

    def asus_nats_websocket
      @configuration.port("asus-node", "loopback_tcp", "nats_websocket")
    end

    def caddy_version
      @configuration.native_artifact("caddy_linux_amd64").fetch("version")
    end

    def frp_version
      @configuration.native_artifact("frp_linux_amd64").fetch("version")
    end

    def postgres_image
      @configuration.image_reference("postgres")
    end

    def nats_image
      @configuration.image_reference("nats")
    end

    def authentik_image
      @configuration.image_reference("authentik")
    end

    def controller_image
      @configuration.image_reference("controller_agent_cli")
    end

    def langgraph_image
      @configuration.image_reference("langgraph")
    end
  end

  class NCM3Renderer
    TEMPLATE_MAP = {
      "vps/Caddyfile.erb" => "vps/caddy/Caddyfile",
      "vps/node-control.Caddyfile.erb" => "vps/caddy/node-control.Caddyfile",
      "vps/frps.toml.erb" => "vps/frps.toml",
      "vps/caddy.service-drop-in.erb" => "vps/systemd/caddy.service.d/50-node-control.conf",
      "vps/node-control-frps.service.erb" => "vps/systemd/node-control-frps.service",
      "asus/frpc.toml.erb" => "asus/frpc.toml",
      "asus/node-control-frpc.service.erb" => "asus/systemd/user/node-control-frpc.service",
      "asus/node-control-core.target.erb" => "asus/systemd/user/node-control-core.target"
    }.freeze

    def initialize(configuration:, templates_dir:, nats_config_path:)
      @configuration = configuration
      @templates_dir = templates_dir
      @nats_config_path = nats_config_path
    end

    def render(output_directory)
      unless %w[split-edge vps-core].include?(@configuration.spec.fetch("placement_profile"))
        raise ArgumentError, "NC-M3 legacy renderer cannot render the approved placement; use the decomposed NC-M3A–NC-M3F path"
      end
      blockers = @configuration.blockers
      raise ArgumentError, "NC-M3 render blocked: #{blockers.join('; ')}" unless blockers.empty?
      raise ArgumentError, "output directory already exists: #{output_directory}" if File.exist?(output_directory)

      FileUtils.mkdir_p(output_directory, mode: 0o700)
      context = NCM3RenderContext.new(@configuration)
      template_map.each do |source, destination|
        render_file(source, File.join(output_directory, destination), context)
      end
      copy_file(@nats_config_path, File.join(output_directory, "asus/quadlet/nats-server.conf"), 0o600)
      write_inputs(File.join(output_directory, "rendered-inputs.yml"))
      write_manifest(output_directory)
    rescue StandardError
      FileUtils.remove_entry_secure(output_directory) if File.directory?(output_directory)
      raise
    end

    private

    def template_map
      map = TEMPLATE_MAP.dup
      Dir.glob(File.join(@templates_dir, "asus/quadlet/*.erb")).sort.each do |path|
        relative = path.delete_prefix(@templates_dir + "/")
        destination = relative.delete_suffix(".erb")
        map[relative] = destination
      end
      map
    end

    def render_file(relative_source, destination, context)
      source = File.join(@templates_dir, relative_source)
      template = ERB.new(File.read(source), trim_mode: "-")
      content = template.result(context.get_binding)
      if content.include?("<%") || content.include?("unresolved") || content.include?("example.invalid")
        raise "unsafe unresolved render in #{relative_source}"
      end
      mode = destination.end_with?("initdb.sh") ? 0o700 : 0o600
      write_file(destination, content, mode)
    end

    def copy_file(source, destination, mode)
      write_file(destination, File.read(source), mode)
    end

    def write_file(path, content, mode)
      FileUtils.mkdir_p(File.dirname(path), mode: 0o700)
      File.open(path, File::WRONLY | File::CREAT | File::EXCL, mode) { |file| file.write(content) }
    end

    def write_inputs(path)
      data = {
        "api_version" => "nodecontrol.io/v1alpha1",
        "kind" => "NC-M3RenderedInputs",
        "base_domain" => @configuration.base_domain,
        "hosts" => %w[control auth bus tunnel].each_with_object({}) do |name, hosts|
          hosts[name] = @configuration.endpoint(name)
        end,
        "images" => %w[postgres nats authentik controller_agent_cli langgraph].each_with_object({}) do |name, images|
          images[name] = @configuration.image_reference(name)
        end,
        "ports_source" => "config/nc-m3/ports.yml",
        "secrets_included" => false
      }
      write_file(path, YAML.dump(data), 0o600)
    end

    def write_manifest(output_directory)
      entries = Dir.glob(File.join(output_directory, "**/*")).select { |path| File.file?(path) }.sort.map do |path|
        relative = path.delete_prefix(output_directory + "/")
        "#{Digest::SHA256.file(path).hexdigest}  #{relative}"
      end
      write_file(File.join(output_directory, "MANIFEST.sha256"), entries.join("\n") + "\n", 0o600)
    end
  end
end
