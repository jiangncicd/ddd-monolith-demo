package com.example.app.trigger.mq;

import com.example.app.application.order.IOrderPlaceUseCase;
import com.example.app.application.order.OrderResult;
import com.example.app.application.order.PlaceOrderCommand;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import javax.annotation.Resource;
import java.util.ArrayList;
import java.util.List;

/**
 * MQ 触发器：消费"下单消息"，异步驱动下单用例。
 * <p>
 * 与 {@code OrderController} 一样，只做"协议 → Command"的转换，然后<b>复用同一个
 * {@link IOrderPlaceUseCase}</b>——这正是原文"触发 → 函数 → 连接"里，HTTP / MQ / RPC / Task
 * 都只是不同"触发"方式的体现。
 * <p>
 * 这里用"瘦监听器 + 委托"写法：{@link #onMessage(String)} 是集成缝，接入真实中间件时把监听注解贴上即可，例如：
 * <pre>
 *   // RocketMQ： 类上 @RocketMQMessageListener(topic="order_place", consumerGroup="cg_order")
 *   //           并 implements RocketMQListener&lt;String&gt;，在 onMessage 里转调本方法
 *   // Kafka：    @KafkaListener(topics = "order_place")
 *   // RabbitMQ： @RabbitListener(queues = "order_place")
 * </pre>
 */
@Slf4j
@Component
public class OrderPlaceConsumer {

    @Resource
    private IOrderPlaceUseCase orderPlaceUseCase;

    @Resource
    private ObjectMapper objectMapper;

    /** 消息入口：真实项目由中间件监听注解回调此方法，测试可直接调用。 */
    public void onMessage(String message) {
        log.info("[MQ] 收到下单消息：{}", message);
        try {
            OrderPlaceMessage msg = objectMapper.readValue(message, OrderPlaceMessage.class);

            List<PlaceOrderCommand.Item> items = new ArrayList<>();
            if (msg.getItems() != null) {
                for (OrderPlaceMessage.Item i : msg.getItems()) {
                    items.add(PlaceOrderCommand.Item.builder()
                            .productName(i.getProductName())
                            .quantity(i.getQuantity())
                            .price(i.getPrice())
                            .build());
                }
            }
            PlaceOrderCommand command = PlaceOrderCommand.builder()
                    .userId(msg.getUserId())
                    .items(items)
                    .build();

            OrderResult result = orderPlaceUseCase.placeOrder(command);
            log.info("[MQ] 下单处理结果：{}", result);
            // 真实项目：result 失败时根据业务决定 ACK / 重试 / 转投死信队列
        } catch (Exception e) {
            // 消息解析或处理异常：记录并交由中间件的重试/死信机制处理（此处不吞异常语义可按需调整）
            log.error("[MQ] 下单消息处理失败，message={}", message, e);
        }
    }
}
