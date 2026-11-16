# ---------------------------------------------------------------------------
# Fase 4: topico unico de mensagens entre os microsservicos
# (docs/fase-4/CONTRATOS.md, secao 5, no repo oficina-api).
#
# O topico mora na fundacao porque e compartilhado e precisa sobreviver ao
# cluster. A fila, a DLQ e a assinatura de cada servico nascem no infra/ do
# repo do proprio servico, que le o ARN daqui pelo SSM.
#
# Topico padrao, nao FIFO: a ordem e garantida pela maquina de estados da saga
# e a duplicidade pela inbox de cada consumidor (ADR-013, ADR-017).
# ---------------------------------------------------------------------------

resource "aws_sns_topic" "messages" {
  name = "${local.name_prefix}-mensagens"

  tags = { Name = "${local.name_prefix}-mensagens" }
}

resource "aws_ssm_parameter" "messaging_topic_arn" {
  name  = "/oficina/${var.environment}/messaging/topic_arn"
  type  = "String"
  value = aws_sns_topic.messages.arn
}
