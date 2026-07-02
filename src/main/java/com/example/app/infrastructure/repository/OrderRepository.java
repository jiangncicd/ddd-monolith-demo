package com.example.app.infrastructure.repository;

import com.example.app.domain.order.model.aggregate.OrderAggregate;
import com.example.app.domain.order.model.entity.OrderItemEntity;
import com.example.app.domain.order.repository.IOrderRepository;
import com.example.app.infrastructure.dao.OrderDao;
import com.example.app.infrastructure.po.OrderItemPO;
import com.example.app.infrastructure.po.OrderPO;
import org.springframework.stereotype.Repository;

import javax.annotation.Resource;
import java.util.UUID;

/**
 * 订单仓储实现：聚合 -> PO 的拆解与落库都在这一层完成。
 */
@Repository
public class OrderRepository implements IOrderRepository {

    @Resource
    private OrderDao orderDao;

    @Override
    public String nextOrderId() {
        return "ORD" + UUID.randomUUID().toString().replace("-", "").substring(0, 12).toUpperCase();
    }

    @Override
    public void save(OrderAggregate order) {
        OrderPO orderPO = new OrderPO();
        orderPO.setOrderId(order.getOrderId());
        orderPO.setUserId(order.getUserId());
        orderPO.setStatus(order.getStatus().name());
        orderPO.setTotalAmount(order.totalAmount().getAmount());
        orderDao.insertOrder(orderPO);

        for (OrderItemEntity item : order.getItems()) {
            OrderItemPO itemPO = new OrderItemPO();
            itemPO.setOrderId(order.getOrderId());
            itemPO.setProductName(item.getProductName());
            itemPO.setQuantity(item.getQuantity());
            itemPO.setPrice(item.getPrice().getAmount());
            orderDao.insertItem(itemPO);
        }
    }

    @Override
    public long count() {
        return orderDao.countOrders();
    }
}
