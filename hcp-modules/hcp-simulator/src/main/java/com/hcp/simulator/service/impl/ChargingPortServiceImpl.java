package com.hcp.simulator.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.hcp.simulator.mapper.ChargingPortMapper;
import com.hcp.simulator.service.ChargingPortService;
import com.hcp.system.api.domain.ChargingPort;
import org.springframework.stereotype.Service;

import java.util.List;

/**
 * 充电桩端口表 服务实现
 *
 * @author hcp
 * @date 2026-08-06
 */
@Service
public class ChargingPortServiceImpl extends ServiceImpl<ChargingPortMapper, ChargingPort> implements ChargingPortService {

    /**
     * 按桩编号查询端口（多枪即返回多行）
     *
     * @param pileId 充电桩编号
     * @return 端口集合
     */
    @Override
    public List<ChargingPort> getByDeviceId(String pileId) {
        return list(new LambdaQueryWrapper<ChargingPort>()
                .eq(ChargingPort::getPileId, pileId)
                .orderByAsc(ChargingPort::getDeviceId));
    }

    /**
     * 更新插枪状态
     *
     * @param pileId    充电桩编号
     * @param deviceId  枪口编号
     * @param gunStatus 枪状态
     * @param state     端口状态
     */
    @Override
    public void updateGunStatus(String pileId, String deviceId, Long gunStatus, String state) {
        ChargingPort port = new ChargingPort();
        port.setGunStatus(gunStatus);
        port.setState(state);
        lambdaUpdate()
                .eq(ChargingPort::getPileId, pileId)
                .eq(ChargingPort::getDeviceId, deviceId)
                .update(port);
    }
}
