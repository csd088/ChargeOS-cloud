package com.hcp.simulator.service.impl;

import com.baomidou.mybatisplus.core.conditions.update.LambdaUpdateWrapper;
import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.hcp.simulator.mapper.ChargingOrderMapper;
import com.hcp.simulator.service.ChargingOrderService;
import com.hcp.system.api.domain.ChargingOrder;
import org.springframework.stereotype.Service;

/**
 * 充电订单表 服务实现
 *
 * @author hcp
 * @date 2026-08-06
 */
@Service
public class ChargingOrderServiceImpl extends ServiceImpl<ChargingOrderMapper, ChargingOrder> implements ChargingOrderService {

    /**
     * 将桩下所有未结束订单复位为"未结束/取消"状态
     * （模拟器重新启动时清理残留的充电中订单）
     *
     * @param pileId 充电桩编号
     */
    @Override
    public void updateNoEndOrder(String pileId) {
        ChargingOrder update = new ChargingOrder();
        update.setOrderState("5");
        lambdaUpdate()
                .eq(ChargingOrder::getPileId, pileId)
                .in(ChargingOrder::getOrderState, "1", "2", "3", "4", "6", "7")
                .or(w -> w.eq(ChargingOrder::getChargeStatus, "9001").eq(ChargingOrder::getChargeStatus, "9002"))
                .update(update);
    }
}
