moved {
  from = aws_cloudwatch_log_group.zoom_node
  to   = module.zoom_node.aws_cloudwatch_log_group.zoom_node
}

moved {
  from = aws_instance.zoom_node
  to   = module.zoom_node.aws_instance.zoom_node
}

moved {
  from = aws_network_interface.zoom_node
  to   = module.zoom_node.aws_network_interface.zoom_node
}
