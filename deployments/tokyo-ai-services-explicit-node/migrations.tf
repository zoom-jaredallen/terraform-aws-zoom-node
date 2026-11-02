moved {
  from = aws_cloudwatch_log_group.ai_services
  to   = aws_cloudwatch_log_group.ai_services["jp01worker1-ap-northeast-1a"]
}

moved {
  from = aws_instance.ai_services
  to   = aws_instance.ai_services["jp01worker1-ap-northeast-1a"]
}

moved {
  from = aws_network_interface.ai_services
  to   = aws_network_interface.ai_services["jp01worker1-ap-northeast-1a"]
}

moved {
  from = aws_cloudwatch_log_group.ai_services["jp01worker1-ap-northeast-1a"]
  to   = module.zoom_node.module.node.aws_cloudwatch_log_group.zoom_node["jp01worker1-ap-northeast-1a"]
}

moved {
  from = aws_instance.ai_services["jp01worker1-ap-northeast-1a"]
  to   = module.zoom_node.module.node.aws_instance.zoom_node["jp01worker1-ap-northeast-1a"]
}

moved {
  from = aws_network_interface.ai_services["jp01worker1-ap-northeast-1a"]
  to   = module.zoom_node.module.node.aws_network_interface.zoom_node["jp01worker1-ap-northeast-1a"]
}

moved {
  from = aws_cloudwatch_log_group.ai_services["jp01worker2-ap-northeast-1a"]
  to   = module.zoom_node.module.node.aws_cloudwatch_log_group.zoom_node["jp01worker2-ap-northeast-1a"]
}

moved {
  from = aws_instance.ai_services["jp01worker2-ap-northeast-1a"]
  to   = module.zoom_node.module.node.aws_instance.zoom_node["jp01worker2-ap-northeast-1a"]
}

moved {
  from = aws_network_interface.ai_services["jp01worker2-ap-northeast-1a"]
  to   = module.zoom_node.module.node.aws_network_interface.zoom_node["jp01worker2-ap-northeast-1a"]
}
