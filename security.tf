locals {
  empty_rule = []

  management_ingress_rules = concat(
    [
      for cidr in var.source_cidrs.remote_management_1 : {
        description = "remote management TCP/8443"
        protocol    = "tcp"
        from_port   = 8443
        to_port     = 8443
        cidr_blocks = [cidr]
      }
    ],
    [
      for cidr in var.source_cidrs.remote_management_2 : {
        description = "remote management TCP/8443 secondary"
        protocol    = "tcp"
        from_port   = 8443
        to_port     = 8443
        cidr_blocks = [cidr]
      }
    ]
  )

  advanced_management_ingress_rules = concat(
    [for cidr in var.source_cidrs.remote_management_1 : { description = "management all TCP", protocol = "tcp", from_port = 0, to_port = 65535, cidr_blocks = [cidr] }],
    [for cidr in var.source_cidrs.remote_management_1 : { description = "management all UDP", protocol = "udp", from_port = 0, to_port = 65535, cidr_blocks = [cidr] }],
    [for cidr in var.source_cidrs.remote_management_2 : { description = "management all TCP secondary", protocol = "tcp", from_port = 0, to_port = 65535, cidr_blocks = [cidr] }],
    [for cidr in var.source_cidrs.remote_management_2 : { description = "management all UDP secondary", protocol = "udp", from_port = 0, to_port = 65535, cidr_blocks = [cidr] }]
  )

  workload_ingress_rules = {
    MeetingsHybrid = concat(
      [for cidr in var.source_cidrs.zoom_clients : { description = "meetings hybrid TCP/80", protocol = "tcp", from_port = 80, to_port = 80, cidr_blocks = [cidr] }],
      [for cidr in var.source_cidrs.zoom_clients : { description = "meetings hybrid TCP/443", protocol = "tcp", from_port = 443, to_port = 443, cidr_blocks = [cidr] }],
      [for cidr in var.source_cidrs.zoom_clients : { description = "meetings hybrid UDP/8801-8803", protocol = "udp", from_port = 8801, to_port = 8803, cidr_blocks = [cidr] }]
    )
    HybridRecording = [
      for cidr in var.source_cidrs.zoom_clients : {
        description = "hybrid recording TCP/443"
        protocol    = "tcp"
        from_port   = 443
        to_port     = 443
        cidr_blocks = [cidr]
      }
    ]
    MeetingSurvivability = concat(
      [for cidr in var.source_cidrs.zoom_clients : { description = "meeting survivability TCP/443", protocol = "tcp", from_port = 443, to_port = 443, cidr_blocks = [cidr] }],
      [for cidr in var.source_cidrs.remote_management_1 : { description = "meeting survivability TCP/8080", protocol = "tcp", from_port = 8080, to_port = 8080, cidr_blocks = [cidr] }],
      [for cidr in var.source_cidrs.remote_management_2 : { description = "meeting survivability TCP/8080 secondary", protocol = "tcp", from_port = 8080, to_port = 8080, cidr_blocks = [cidr] }],
      [for cidr in local.internal_traffic_cidrs : { description = "meeting survivability TCP/3306", protocol = "tcp", from_port = 3306, to_port = 3306, cidr_blocks = [cidr] }]
    )
    WebApplicationGateway = concat(
      [for cidr in var.source_cidrs.zoom_clients : { description = "web application gateway TCP/443", protocol = "tcp", from_port = 443, to_port = 443, cidr_blocks = [cidr] }],
      [for cidr in var.source_cidrs.zoom_clients : { description = "web application gateway TCP/8801-8802", protocol = "tcp", from_port = 8801, to_port = 8802, cidr_blocks = [cidr] }],
      [for cidr in var.source_cidrs.zoom_clients : { description = "web application gateway UDP/8801-8810", protocol = "udp", from_port = 8801, to_port = 8810, cidr_blocks = [cidr] }]
    )
    AiServices = []
    PhoneLocalSurvivability = concat(
      [for cidr in var.source_cidrs.zoom_clients : { description = "phone local survivability TCP/5091", protocol = "tcp", from_port = 5091, to_port = 5091, cidr_blocks = [cidr] }],
      [for cidr in var.source_cidrs.zoom_clients : { description = "phone local survivability UDP/20000-64000", protocol = "udp", from_port = 20000, to_port = 64000, cidr_blocks = [cidr] }],
      [for cidr in local.internal_traffic_cidrs : { description = "phone local survivability TCP/9443", protocol = "tcp", from_port = 9443, to_port = 9443, cidr_blocks = [cidr] }],
      [for cidr in var.source_cidrs.sbc : { description = "phone local survivability TCP/5061", protocol = "tcp", from_port = 5061, to_port = 5061, cidr_blocks = [cidr] }],
      [for cidr in var.source_cidrs.sbc : { description = "phone local survivability UDP/20000-64000", protocol = "udp", from_port = 20000, to_port = 64000, cidr_blocks = [cidr] }]
    )
  }

  internal_traffic_cidrs = length(var.source_cidrs.internal_traffic) > 0 ? var.source_cidrs.internal_traffic : [local.effective_vpc_cidr]

  kubernetes_internal_ingress_rules = [
    for cidr in local.internal_traffic_cidrs : {
      description = "kubernetes internal all traffic"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      cidr_blocks = [cidr]
    }
  ]

  advanced_ingress_rules = {
    meetings_hybrid = concat(
      local.advanced_management_ingress_rules,
      local.workload_ingress_rules.MeetingsHybrid
    )
    kubernetes_master = concat(
      local.advanced_management_ingress_rules,
      local.kubernetes_internal_ingress_rules
    )
    kubernetes_worker = [
      for cidr in local.internal_traffic_cidrs : {
        description = "kubernetes internal all traffic"
        protocol    = "-1"
        from_port   = 0
        to_port     = 0
        cidr_blocks = [cidr]
      }
    ]
  }

  security_group_configs = merge(
    {
      for workload_type, workload in local.enabled_workloads : workload_type => {
        prefix   = workload.prefix
        advanced = false
      }
    },
    {
      for profile in local.advanced_security_profiles : profile => {
        prefix   = replace(profile, "_", "-")
        advanced = true
      }
    }
  )

  allow_all_egress_rules = [
    {
      description = "all outbound"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]

  workload_egress_rules = {
    MeetingsHybrid = concat(
      [for cidr in var.source_cidrs.zoom_cloud : { description = "meetings hybrid HTTPS to Zoom Cloud", protocol = "tcp", from_port = 443, to_port = 443, cidr_blocks = [cidr] }],
      [for cidr in var.source_cidrs.zoom_cloud : { description = "meetings hybrid media UDP/8801-8810", protocol = "udp", from_port = 8801, to_port = 8810, cidr_blocks = [cidr] }]
    )
    HybridRecording = concat(
      [for cidr in var.source_cidrs.zoom_cloud : { description = "hybrid recording HTTPS to Zoom Cloud", protocol = "tcp", from_port = 443, to_port = 443, cidr_blocks = [cidr] }],
      [for cidr in var.source_cidrs.nfs : { description = "hybrid recording NFS TCP/2049", protocol = "tcp", from_port = 2049, to_port = 2049, cidr_blocks = [cidr] }],
      [for cidr in var.source_cidrs.nfs : { description = "hybrid recording NFS UDP/2049", protocol = "udp", from_port = 2049, to_port = 2049, cidr_blocks = [cidr] }],
      [for cidr in var.source_cidrs.nfs : { description = "hybrid recording portmapper TCP/111", protocol = "tcp", from_port = 111, to_port = 111, cidr_blocks = [cidr] }],
      [for cidr in var.source_cidrs.nfs : { description = "hybrid recording portmapper UDP/111", protocol = "udp", from_port = 111, to_port = 111, cidr_blocks = [cidr] }],
      [for cidr in var.source_cidrs.nfs : { description = "hybrid recording mountd TCP/20048", protocol = "tcp", from_port = 20048, to_port = 20048, cidr_blocks = [cidr] }],
      [for cidr in var.source_cidrs.nfs : { description = "hybrid recording mountd UDP/20048", protocol = "udp", from_port = 20048, to_port = 20048, cidr_blocks = [cidr] }]
    )
    MeetingSurvivability = concat(
      [for cidr in var.source_cidrs.zoom_cloud : { description = "meeting survivability HTTPS to Zoom Cloud", protocol = "tcp", from_port = 443, to_port = 443, cidr_blocks = [cidr] }],
      [for cidr in local.internal_traffic_cidrs : { description = "meeting survivability TCP/8080 internal", protocol = "tcp", from_port = 8080, to_port = 8080, cidr_blocks = [cidr] }],
      [for cidr in local.internal_traffic_cidrs : { description = "meeting survivability TCP/3306 internal", protocol = "tcp", from_port = 3306, to_port = 3306, cidr_blocks = [cidr] }]
    )
    WebApplicationGateway = concat(
      [for cidr in var.source_cidrs.zoom_cloud : { description = "web application gateway HTTPS to Zoom Cloud", protocol = "tcp", from_port = 443, to_port = 443, cidr_blocks = [cidr] }],
      [for cidr in var.source_cidrs.zoom_cloud : { description = "web application gateway TCP/8801-8802", protocol = "tcp", from_port = 8801, to_port = 8802, cidr_blocks = [cidr] }],
      [for cidr in var.source_cidrs.zoom_cloud : { description = "web application gateway UDP/8801-8810", protocol = "udp", from_port = 8801, to_port = 8810, cidr_blocks = [cidr] }]
    )
    AiServices = [
      for cidr in var.source_cidrs.zoom_cloud : {
        description = "ai services HTTPS to Zoom Cloud"
        protocol    = "tcp"
        from_port   = 443
        to_port     = 443
        cidr_blocks = [cidr]
      }
    ]
    PhoneLocalSurvivability = concat(
      [for cidr in var.source_cidrs.zoom_cloud : { description = "phone local survivability HTTPS to Zoom Cloud", protocol = "tcp", from_port = 443, to_port = 443, cidr_blocks = [cidr] }],
      [for cidr in var.source_cidrs.zoom_cloud : { description = "phone local survivability TCP/9669 to Zoom Cloud", protocol = "tcp", from_port = 9669, to_port = 9669, cidr_blocks = [cidr] }],
      [for cidr in var.source_cidrs.zoom_cloud : { description = "phone local survivability TCP/5091 to Zoom Cloud", protocol = "tcp", from_port = 5091, to_port = 5091, cidr_blocks = [cidr] }],
      [for cidr in var.source_cidrs.sbc : { description = "phone local survivability TCP/5061 to SBC", protocol = "tcp", from_port = 5061, to_port = 5061, cidr_blocks = [cidr] }],
      [for cidr in var.source_cidrs.sbc : { description = "phone local survivability UDP/20000-64000 to SBC", protocol = "udp", from_port = 20000, to_port = 64000, cidr_blocks = [cidr] }]
    )
  }

  advanced_egress_rules = {
    meetings_hybrid = local.workload_egress_rules.MeetingsHybrid
    kubernetes_master = concat(
      [for cidr in local.internal_traffic_cidrs : { description = "kubernetes internal all traffic", protocol = "-1", from_port = 0, to_port = 0, cidr_blocks = [cidr] }],
      [for cidr in var.source_cidrs.zoom_cloud : { description = "kubernetes HTTPS to Zoom Cloud", protocol = "tcp", from_port = 443, to_port = 443, cidr_blocks = [cidr] }]
    )
    kubernetes_worker = concat(
      [for cidr in local.internal_traffic_cidrs : { description = "kubernetes internal all traffic", protocol = "-1", from_port = 0, to_port = 0, cidr_blocks = [cidr] }],
      [for cidr in var.source_cidrs.zoom_cloud : { description = "kubernetes HTTPS to Zoom Cloud", protocol = "tcp", from_port = 443, to_port = 443, cidr_blocks = [cidr] }]
    )
  }

  effective_security_group_egress_profiles = {
    for security_group_key, config in local.security_group_configs : security_group_key => (
      lookup(var.aws.security_group_egress_profiles, security_group_key, null) != null ?
      var.aws.security_group_egress_profiles[security_group_key] :
      var.enable_least_privilege_egress && !config.advanced ? "workload_specific" : "allow_all"
    )
  }

  ingress_rule_record_list = flatten([
    for security_group_key, config in local.security_group_configs : [
      for rule in(
        config.advanced ?
        lookup(local.advanced_ingress_rules, security_group_key, local.empty_rule) :
        concat(local.management_ingress_rules, lookup(local.workload_ingress_rules, security_group_key, local.empty_rule))
        ) : [
        for cidr in rule.cidr_blocks : {
          key                = "${security_group_key}-${rule.protocol}-${rule.from_port}-${rule.to_port}-${substr(sha1(cidr), 0, 12)}"
          security_group_key = security_group_key
          description        = rule.description
          protocol           = rule.protocol
          from_port          = rule.from_port
          to_port            = rule.to_port
          cidr               = cidr
        }
      ]
    ]
  ])

  grouped_ingress_rule_records = {
    for record in local.ingress_rule_record_list : record.key => record...
  }

  ingress_rule_records = {
    for key, records in local.grouped_ingress_rule_records : key => records[0]
  }

  egress_rule_record_list = flatten([
    for security_group_key, config in local.security_group_configs : [
      for rule in(
        local.effective_security_group_egress_profiles[security_group_key] == "deny_all" ? local.empty_rule :
        local.effective_security_group_egress_profiles[security_group_key] == "workload_specific" ? (
          config.advanced ?
          lookup(local.advanced_egress_rules, security_group_key, local.empty_rule) :
          lookup(local.workload_egress_rules, security_group_key, local.empty_rule)
        ) : local.allow_all_egress_rules
        ) : [
        for cidr in rule.cidr_blocks : {
          key                = "${security_group_key}-${rule.protocol}-${rule.from_port}-${rule.to_port}-${substr(sha1(cidr), 0, 12)}"
          security_group_key = security_group_key
          description        = rule.description
          protocol           = rule.protocol
          from_port          = rule.from_port
          to_port            = rule.to_port
          cidr               = cidr
        }
      ]
    ]
  ])

  grouped_egress_rule_records = {
    for record in local.egress_rule_record_list : record.key => record...
  }

  egress_rule_records = {
    for key, records in local.grouped_egress_rule_records : key => records[0]
  }
}

resource "aws_security_group" "zoom_node" {
  for_each    = local.security_group_configs
  name_prefix = var.environment_name == "" ? "${each.value.prefix}-zoom-node-" : "${var.environment_name}-${each.value.prefix}-zoom-node-"
  description = each.value.advanced ? "Zoom Node ${each.key} security profile" : "Zoom Node ${each.key} security group"
  vpc_id      = local.effective_vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = var.environment_name == "" ? "${each.value.prefix}-zoom-node-sg" : "${var.environment_name}-${each.value.prefix}-zoom-node-sg"
    },
    each.value.advanced ? { Profile = each.key } : { Workload = each.key }
  )
}

resource "aws_vpc_security_group_ingress_rule" "zoom_node" {
  for_each = local.ingress_rule_records

  security_group_id = aws_security_group.zoom_node[each.value.security_group_key].id
  description       = each.value.description
  ip_protocol       = each.value.protocol
  from_port         = each.value.protocol == "-1" ? null : each.value.from_port
  to_port           = each.value.protocol == "-1" ? null : each.value.to_port
  cidr_ipv4         = each.value.cidr

  tags = merge(local.common_tags, {
    Name = each.key
  })
}

resource "aws_vpc_security_group_egress_rule" "zoom_node" {
  for_each = local.egress_rule_records

  security_group_id = aws_security_group.zoom_node[each.value.security_group_key].id
  description       = each.value.description
  ip_protocol       = each.value.protocol
  from_port         = each.value.protocol == "-1" ? null : each.value.from_port
  to_port           = each.value.protocol == "-1" ? null : each.value.to_port
  cidr_ipv4         = each.value.cidr

  tags = merge(local.common_tags, {
    Name = each.key
  })
}
