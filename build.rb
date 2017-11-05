#!/usr/bin/env ruby
require "rubygems" # ruby1.9 doesn't "require" it though
require "thor"
require 'rbconfig'
require 'fileutils'

def os
  case RbConfig::CONFIG['host_os']
    when /mswin|windows/i
      :windows
    when /linux|arch/i
      :linux
    when /darwin/i
      :darwin
    else
      abort("Unsupported OS #{RbConfig::CONFIG['host_os']}")
  end
end

$terraform_version = "0.9.5"
$terraform_url = "https://releases.hashicorp.com/terraform/#{$terraform_version}/terraform_#{$terraform_version}_#{os}_amd64.zip"
$tmp_dir = ".tmp/bin"
$excluded_dirs = ["conf/", "modules/"]
$pwd = Dir.pwd

class Build < Thor
  desc "clean", "Clean all folders"
  def clean
    puts "Cleaning temp folder"
    FileUtils.rm_rf($tmp_dir)
    puts "Cleaning .terraform folders"
    Dir["**/.terraform/"].each { |x| FileUtils.rm_rf(x)}
  end

  desc "install", "Install required dependencies."
  def install
    puts "Running on: #{os}"
    FileUtils.mkdir_p '.tmp/bin'
    puts "\n\n\nAttempting to decrypt secrets using GPG key."
    system("git-crypt unlock") or abort("Error when attempting to decrypt secrets")
    system("chmod 600 conf/provisioning/ssh/terraform-api.key") or abort("Error when setting private key permissions")
    system("wget -vvvv -O #{$tmp_dir}/terraform.zip #{$terraform_url}") or abort("Error when downloading terraform")
    system("cd #{$tmp_dir} && unzip terraform.zip") or abort("Error when unzipping terraform")
    FileUtils.cp('conf/openrc-personal-example', 'conf/openrc-personal') unless File.exists?('conf/openrc-personal')
    puts "\n\n\n*** Please edit conf/openrc-personal with your credentials. ***\n\n"
  end

  desc "init", "Run terraform init"
  def init
    (Dir["*/"] - $excluded_dirs).each { |d|
      puts "Running terraform init on #{d}"
      system("source conf/openrc && cd #{d} && #{$pwd}/#{$tmp_dir}/terraform init -force-copy") or abort
    }
  end

  desc "plan DIR", "run terraform plan on defined directory"
  def plan(dir)
    puts "Running terraform plan on #{dir}"
    system("source conf/openrc && cd #{dir} && #{$pwd}/#{$tmp_dir}/terraform plan -out terraform.plan") or abort
  end

  desc "apply DIR", "run terraform apply on defined directory"
  def apply(dir)
    puts "Terraform apply is NOT thread-safe, and there's no lock mechanism enabled. Two concurrent calls on the same stack will cause inconsistences."
    printf "Do you really want to modify stack #{dir}? [y/N]:  "
    prompt = STDIN.gets.chomp
    return unless prompt == 'y'

    puts "Running terraform apply on #{dir}"
    system("source conf/openrc && cd #{dir} && #{$pwd}/#{$tmp_dir}/terraform apply terraform.plan") or abort
  end

  desc "taint-vm DIR", "mark virtual machine for recreation in DIR"
  def taint_vm(dir)
    puts "Running terraform taint on #{dir} (vm resources)"
    system("""source conf/openrc && cd #{dir} \
      && #{$pwd}/#{$tmp_dir}/terraform taint -module single-machine openstack_compute_instance_v2.vm \
      && #{$pwd}/#{$tmp_dir}/terraform taint -module single-machine null_resource.mount_data_volume \
      && #{$pwd}/#{$tmp_dir}/terraform taint -module single-machine null_resource.upgrade \
      && #{$pwd}/#{$tmp_dir}/terraform taint -module single-machine null_resource.ansible \
    """) or abort
  end

  desc "terraform DIR 'subcommand --args'", "run arbitrary terraform subcommands on defined directory"
  def terraform(dir, args)
    puts "Running terraform \'#{args}\' on #{dir}"
    system("source conf/openrc && cd #{dir} && #{$pwd}/#{$tmp_dir}/terraform #{args}") or abort
  end

  desc "create DIR", "creates files for new stack DIR"
  def create(dir)
    puts "Creating stack \'#{dir}\'"
    FileUtils.mkdir_p dir
    FileUtils.cp_r 'conf/template-stack/.',dir
    IO.write("#{dir}/main.tf", File.open("#{dir}/main.tf") do |f|
        f.read.gsub(/STACK-NAME/, "#{dir}")
      end
    )
    IO.write("#{dir}/variables.tf", File.open("#{dir}/variables.tf") do |f|
        f.read.gsub(/STACK-NAME/, "#{dir}")
      end
    )
    FileUtils.ln_sf '../global-variables.tf',"#{dir}/global-variables.tf"
    system("source conf/openrc && cd #{dir} && #{$pwd}/#{$tmp_dir}/terraform init") or abort
  end
end

Build.start
