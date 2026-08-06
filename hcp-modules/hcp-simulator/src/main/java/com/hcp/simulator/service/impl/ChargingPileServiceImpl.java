package com.hcp.simulator.service.impl;

import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.hcp.simulator.mapper.ChargingPileMapper;
import com.hcp.simulator.service.ChargingPileService;
import com.hcp.system.api.domain.ChargingPile;
import org.springframework.stereotype.Service;

/**
 * 充电桩表 服务实现
 *
 * @author hcp
 * @date 2026-08-06
 */
@Service
public class ChargingPileServiceImpl extends ServiceImpl<ChargingPileMapper, ChargingPile> implements ChargingPileService {

    /**
     * 更新充电桩运行状态
     *
     * @param pileId 充电桩编号
     * @param status 运行状态 0运行 1离线
     */
    @Override
    public void updateRunningStatus(String pileId, long status) {
        ChargingPile pile = new ChargingPile();
        pile.setPileId(pileId);
        pile.setRunningStatus(status);
        baseMapper.updateById(pile);
    }
}
