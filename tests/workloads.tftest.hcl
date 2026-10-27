mock_provider "aws" {
  mock_data "aws_region" {
    defaults = {
      region = "us-west-2"
    }
  }

  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-west-2a", "us-west-2b"]
    }
  }

  mock_data "aws_servicequotas_service_quota" {
    defaults = {
      value = 150
    }
  }

  mock_data "aws_eips" {
    defaults = {
      public_ips = []
    }
  }

  mock_data "aws_ec2_instance_type_offerings" {
    defaults = {
      instance_types = ["c6i.2xlarge", "c6i.xlarge", "g6.12xlarge", "m6i.6xlarge"]
    }
  }
}

mock_provider "random" {}

variables {
  environment_name  = "workloads"
  domain_name       = "example.com"
  registration_code = "ABCDEFGHIJKLMNOP"
  node_password     = "ZoomNode1!"

  source_cidrs = {
    remote_management_1 = ["192.0.2.10/32"]
  }

  hybrid_recording_s3_bucket_name = "zoom-node-contract-existing-recordings"

  aws = {
    availability_zones = ["us-west-2a"]
  }
}

run "plan_meetings_hybrid_workload" {
  command = plan

  variables {
    workloads = {
      meetings_hybrid = {
        enabled  = true
        capacity = 500
      }
    }
  }

  assert {
    condition     = output.workload_node_counts["MeetingsHybrid"] == 2
    error_message = "Meetings Hybrid must retain its two-node minimum at capacity 500."
  }

  assert {
    condition     = module.node.instances["meetings_hybrid-01"].instance_type == "c6i.2xlarge" && module.node.instances["meetings_hybrid-01"].root_volume_size == 200
    error_message = "Meetings Hybrid must use the catalog compute and storage defaults."
  }

  assert {
    condition     = length(module.node.network_interfaces["meetings_hybrid-01"].private_ips) == 5 && module.node.eip_count == 10
    error_message = "Meetings Hybrid must allocate five private and five public IPs per node."
  }
}

run "plan_hybrid_recording_workload" {
  command = plan

  variables {
    workloads = {
      hybrid_recording = {
        enabled  = true
        capacity = 30
      }
    }
  }

  assert {
    condition     = output.workload_node_counts["HybridRecording"] == 2
    error_message = "Hybrid Recording must retain its two-node minimum."
  }

  assert {
    condition     = module.node.instances["hybrid_recording-01"].instance_type == "m6i.6xlarge" && module.node.instances["hybrid_recording-01"].root_volume_size == 200
    error_message = "Hybrid Recording must use the catalog compute and storage defaults."
  }

  assert {
    condition     = length(module.node.network_interfaces["hybrid_recording-01"].private_ips) == 5 && module.node.eip_count == 2
    error_message = "Hybrid Recording must allocate five private and one public IP per node."
  }
}

run "plan_meeting_survivability_workload" {
  command = plan

  variables {
    workloads = {
      meeting_survivability = {
        enabled    = true
        node_count = 1
      }
    }
  }

  assert {
    condition     = output.workload_node_counts["MeetingSurvivability"] == 1
    error_message = "Meeting Survivability must support one explicitly requested node."
  }

  assert {
    condition     = module.node.instances["meeting_survivability-01"].instance_type == "c6i.xlarge" && length(module.node.network_interfaces["meeting_survivability-01"].private_ips) == 5 && module.node.eip_count == 1
    error_message = "Meeting Survivability must use its catalog instance and IP defaults."
  }
}

run "plan_web_application_gateway_workload" {
  command = plan

  variables {
    workloads = {
      web_application_gateway = {
        enabled  = true
        capacity = 200
      }
    }
  }

  assert {
    condition     = output.workload_node_counts["WebApplicationGateway"] == 2
    error_message = "Web Application Gateway must retain its two-node minimum."
  }

  assert {
    condition     = module.node.instances["web_application_gateway-01"].instance_type == "c6i.2xlarge" && length(module.node.network_interfaces["web_application_gateway-01"].private_ips) == 5 && module.node.eip_count == 2
    error_message = "Web Application Gateway must use its catalog instance and IP defaults."
  }
}

run "plan_ai_services_workload" {
  command = plan

  variables {
    workloads = {
      ai_services = {
        enabled    = true
        node_count = 1
      }
    }
  }

  assert {
    condition     = output.workload_node_counts["AiServices"] == 1
    error_message = "AI Services must support one explicitly requested node."
  }

  assert {
    condition     = module.node.instances["ai_services-01"].instance_type == "g6.12xlarge" && module.node.instances["ai_services-01"].root_volume_size == 500
    error_message = "AI Services must use the GPU catalog instance and 500 GB root volume."
  }

  assert {
    condition     = length(module.node.network_interfaces["ai_services-01"].private_ips) == 1 && module.node.eip_count == 0
    error_message = "AI Services must default to one private IP and no public IPs."
  }
}

run "plan_phone_local_survivability_workload" {
  command = plan

  variables {
    workloads = {
      phone_local_survivability = {
        enabled  = true
        capacity = 5000
      }
    }
  }

  assert {
    condition     = output.workload_node_counts["PhoneLocalSurvivability"] == 2
    error_message = "Phone Local Survivability must retain its two-node minimum."
  }

  assert {
    condition     = module.node.instances["phone_local_survivability-01"].instance_type == "c6i.2xlarge" && length(module.node.network_interfaces["phone_local_survivability-01"].private_ips) == 5 && module.node.eip_count == 2
    error_message = "Phone Local Survivability must use its catalog instance and IP defaults."
  }
}
