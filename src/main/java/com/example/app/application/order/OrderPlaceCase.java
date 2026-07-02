package com.example.app.application.order;

import com.example.app.application.order.assembler.OrderAssembler;
import com.example.app.domain.order.model.aggregate.OrderAggregate;
import com.example.app.domain.order.model.entity.OrderItemEntity;
import com.example.app.domain.order.model.valobj.Money;
import com.example.app.domain.order.service.OrderService;
import com.example.app.domain.rule.model.entity.DecisionMatterEntity;
import com.example.app.domain.rule.model.entity.EngineResultEntity;
import com.example.app.domain.rule.service.RuleService;
import com.example.app.domain.user.model.valobj.UserVO;
import com.example.app.domain.user.service.UserService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import javax.annotation.Resource;
import java.util.ArrayList;
import java.util.List;

/**
 * 用例编排层（对应原 xfg-frame-case 模块，包名用 application 因为 case 是 Java 关键字）。
 * <p>
 * 职责：把 user / rule / order 三个领域按"下单"这个用例串起来，并划定事务边界。
 * 纪律：只做编排，不写领域业务规则（规则在 RuleService，算钱在 OrderAggregate）。
 */
@Slf4j
@Service
public class OrderPlaceCase implements IOrderPlaceUseCase {

    @Resource
    private UserService userService;
    @Resource
    private RuleService ruleService;
    @Resource
    private OrderService orderService;

    @Override
    @Transactional(rollbackFor = Exception.class)
    public OrderResult placeOrder(PlaceOrderCommand command) {
        // 1) 用户领域：查用户
        UserVO user = userService.queryUser(command.getUserId());
        if (user == null) {
            return OrderAssembler.toRejected("用户不存在：" + command.getUserId());
        }

        // 2) 规则领域：下单准入决策
        EngineResultEntity decision = ruleService.process(DecisionMatterEntity.builder()
                .userId(user.getUserId())
                .age(user.getAge())
                .gender(user.getGender())
                .build());
        if (!decision.isAllow()) {
            return OrderAssembler.toRejected(decision.getInfo());
        }

        // 3) 订单领域：创建并持久化订单
        List<OrderItemEntity> items = new ArrayList<>();
        for (PlaceOrderCommand.Item i : command.getItems()) {
            items.add(OrderItemEntity.builder()
                    .productName(i.getProductName())
                    .quantity(i.getQuantity())
                    .price(Money.of(i.getPrice()))
                    .build());
        }
        OrderAggregate order = orderService.createOrder(user.getUserId(), items);
        log.info("下单成功 userId={} orderId={} total={}",
                user.getUserId(), order.getOrderId(), order.totalAmount().getAmount());

        // 4) 装配出参（防腐）
        return OrderAssembler.toSuccess(order);
    }
}
