import { JsBridge } from './IsBridge';
import { LifeCycle } from './LifeCycle';
import { JsModule } from './JsModule';
import { ITipsJsBridge, MemoryInfo } from './Types';
import { webview } from '@kit.ArkWeb';
import { HashMap } from '@kit.ArkTS';

/**
 * JavaScript桥接实现类
 * 实现JsBridge和LifeCycle接口
 * 与JsModule形成循环引用导致内存泄漏
 */
export class TipsJsBridge implements JsBridge, LifeCycle, ITipsJsBridge {
  // 核心问题：supportApiMap存放JsModule，而JsModule又持有bridge引用，形成循环引用
  private supportApiMap: HashMap<string, Set<JsModule>> = new HashMap();
  private webController: webview.WebviewController | null = null;
  private isDestroyed: boolean = false;
  private pendingModules: Map<string, Object> = new Map();
  private webComponentReady: boolean = false;
  private bridgeId: string = ''; // Bridge唯一标识
  private leakMarker: string = 'TIPS_JS_BRIDGE_LEAK'; // 泄漏标记

  constructor() {
    this.bridgeId = `TipsJsBridge_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    console.log(`⚠️ [LEAK_ANALYSIS] TipsJsBridge created with ID: ${this.bridgeId}`);
    console.log(`⚠️ [LEAK_ANALYSIS] Leak marker: ${this.leakMarker}`);
  }

  /**
   * 设置Web控制器
   */
  setWebController(controller: webview.WebviewController): void {
    this.webController = controller;
    console.log('TipsJsBridge web controller set');
  }

  /**
   * 通知Web组件准备完成，可以注册JavaScript代理
   */
  onWebComponentReady(): void {
    this.webComponentReady = true;
    console.log('Web组件准备完成，开始注册待处理的模块');
    
    // 注册所有待处理的模块
    this.pendingModules.forEach((module, moduleName) => {
      if (this.webController) {
        try {
          this.webController.registerJavaScriptProxy(module, moduleName, ['callNative']);
          console.log(`延迟注册模块成功: ${moduleName}`);
        } catch (error) {
          console.error(`注册模块失败: ${moduleName}, 错误: ${error}`);
        }
      }
    });
    
    this.pendingModules.clear();
  }

  // ============ JsBridge接口实现 ============

  /**
   * 注册JS模块 - 这里会形成循环引用
   */
  registerModule(moduleName: string, module: Object): void {
    console.log(`⚠️ [LEAK_ANALYSIS] TipsJsBridge [${this.bridgeId}] registering module: ${moduleName}`);
    
    // 为了让内存泄漏更明显，每个模块创建多个实例
    const moduleInstanceCount = 5;
    
    if (!this.supportApiMap.hasKey(moduleName)) {
      this.supportApiMap.set(moduleName, new Set<JsModule>());
    }
    
    const moduleSet = this.supportApiMap.get(moduleName);
    if (moduleSet !== undefined) {
      // 创建多个 JsModule 实例，每个都持有 bridge 引用
      for (let i = 0; i < moduleInstanceCount; i++) {
        const jsModule = new JsModule(`${moduleName}_instance_${i}`, this);
        moduleSet.add(jsModule);
        
        // 模拟一些大量数据存储，增加内存占用（带有Profile标识）
        const largeData: string[] = new Array(1000).fill(`${this.leakMarker}_大量数据_${moduleName}_${i}`);
        jsModule.setData(`${this.leakMarker}_largeDataArray`, largeData);
        jsModule.setData(`${this.leakMarker}_timestamp`, new Date().toString());
        jsModule.setData(`${this.leakMarker}_moduleIndex`, i);
        jsModule.setData(`${this.leakMarker}_bridgeId`, this.bridgeId);
        jsModule.setData(`${this.leakMarker}_randomData`, Math.random().toString(36).repeat(100));
        
        console.log(`⚠️ [LEAK_ANALYSIS] Created JsModule instance: ${jsModule.getUniqueId()}`);
      }
      
      console.log(`⚠️ [LEAK_ANALYSIS] Module ${moduleName} added ${moduleInstanceCount} instances. Total in set: ${moduleSet.size}`);
      console.log(`⚠️ [LEAK_ANALYSIS] Current supportApiMap size: ${this.supportApiMap.length}`);
    }

    // 根据Web组件状态决定立即注册还是延迟注册
    if (this.webComponentReady && this.webController) {
      try {
        this.webController.registerJavaScriptProxy(module, moduleName, ['callNative']);
        console.log(`立即注册模块成功: ${moduleName}`);
      } catch (error) {
        console.error(`注册模块失败: ${moduleName}, 错误: ${error}`);
        // 如果立即注册失败，加入待处理队列
        this.pendingModules.set(moduleName, module);
      }
    } else {
      // Web组件未准备好，先存储到待处理队列
      console.log(`Web组件未准备好，模块 ${moduleName} 加入待处理队列`);
      this.pendingModules.set(moduleName, module);
    }
  }

  /**
   * 注销JS模块 - 在内存泄漏场景中不会被正确调用
   */
  unregisterModule(moduleName: string): void {
    console.log(`TipsJsBridge unregistering module: ${moduleName}`);
    
    const moduleSet = this.supportApiMap.get(moduleName);
    if (moduleSet !== undefined) {
      // 应该正确销毁模块，但在泄漏场景中这个方法不会被调用
      moduleSet.forEach(module => {
        module.destroy();
      });
      moduleSet.clear();
      this.supportApiMap.remove(moduleName);
      console.log(`Module ${moduleName} unregistered successfully`);
    }

    // 从Web组件注销
    if (this.webController) {
      this.webController.deleteJavaScriptRegister(moduleName);
    }
  }

  /**
   * 调用JavaScript方法
   */
  callJsMethod(moduleName: string, methodName: string, params?: Object): void {
    if (this.isDestroyed) {
      console.log('TipsJsBridge already destroyed, cannot call JS method');
      return;
    }

    console.log(`TipsJsBridge calling JS method: ${moduleName}.${methodName}`);
    
    if (this.webController) {
      const jsCode = `
        if (window.${moduleName} && window.${moduleName}.${methodName}) {
          window.${moduleName}.${methodName}(${params ? JSON.stringify(params) : ''});
        }
      `;
      
      this.webController.runJavaScript(jsCode);
    }
  }

  /**
   * 获取所有注册的模块
   */
  getAllModules(): Map<string, Object> {
    const result = new Map<string, Object>();
    this.supportApiMap.forEach((moduleSet: Set<JsModule>, moduleName: string) => {
      const modules: JsModule[] = [];
      moduleSet.forEach(module => {
        modules.push(module);
      });
      result.set(moduleName, modules);
    });
    return result;
  }

  // ============ LifeCycle接口实现 ============

  onCreate(): void {
    console.log('TipsJsBridge onCreate');
    this.isDestroyed = false;
  }

  onStart(): void {
    console.log('TipsJsBridge onStart');
  }

  onResume(): void {
    console.log('TipsJsBridge onResume');
  }

  onPause(): void {
    console.log('TipsJsBridge onPause');
  }

  onStop(): void {
    console.log('TipsJsBridge onStop');
  }

  /**
   * 销毁方法 - 关键：这里应该清理supportApiMap，但在内存泄漏场景中不会被正确调用
   */
  onDestroy(): void {
    console.log('TipsJsBridge onDestroy called');
    this.isDestroyed = true;
    this.webComponentReady = false;
    
    // 正确的销毁应该清理所有模块
    // 但在内存泄漏场景中，Web组件销毁时这个方法不会被调用
    this.supportApiMap.forEach((moduleSet: Set<JsModule>, moduleName: string) => {
      console.log(`Destroying modules for ${moduleName}, count: ${moduleSet.size}`);
      moduleSet.forEach(module => {
        module.destroy();
      });
      moduleSet.clear();
    });
    
    this.supportApiMap.clear();
    this.pendingModules.clear();
    this.webController = null;
    console.log('TipsJsBridge destroyed completely');
  }

  // ============ 用于演示内存泄漏的方法 ============

  /**
   * 模拟内存泄漏场景：Web组件销毁但supportApiMap没有清空
   */
  simulateMemoryLeak(): void {
    console.log('\n\n=== ⚠️ [LEAK_ANALYSIS] 内存泄漏场景分析 ===');
    console.log(`⚠️ [LEAK_ANALYSIS] TipsJsBridge ID: ${this.bridgeId}`);
    console.log(`⚠️ [LEAK_ANALYSIS] Leak Marker: ${this.leakMarker}`);
    console.log(`⚠️ [LEAK_ANALYSIS] 当前supportApiMap大小: ${this.supportApiMap.length}`);
    
    let totalInstances = 0;
    let totalMemoryItems = 0;
    
    this.supportApiMap.forEach((moduleSet: Set<JsModule>, moduleName: string) => {
      console.log(`\n⚠️ [LEAK_ANALYSIS] 模块 ${moduleName} 包含 ${moduleSet.size} 个JsModule实例`);
      totalInstances += moduleSet.size;
      
      moduleSet.forEach(module => {
        const uniqueId = module.getUniqueId();
        const leakMarker = module.getLeakMarker();
        const bridgeRef = module.getBridge() !== null;
        
        console.log(`  ⚠️ [LEAK_ANALYSIS] JsModule ID: ${uniqueId}`);
        console.log(`  ⚠️ [LEAK_ANALYSIS] Leak Marker: ${leakMarker}`);
        console.log(`  ⚠️ [LEAK_ANALYSIS] Bridge Reference Active: ${bridgeRef}`);
        
        // 计算每个模块的内存占用
        const moduleData = module.getData(`${leakMarker}_largeDataArray`);
        if (moduleData && Array.isArray(moduleData)) {
          const dataArray = moduleData as string[];
          totalMemoryItems += dataArray.length;
          console.log(`  ⚠️ [LEAK_ANALYSIS] Large Data Array Size: ${dataArray.length}`);
        }
      });
    });
    
    console.log(`\n⚠️ [LEAK_ANALYSIS] === 泄漏统计信息 ===`);
    console.log(`⚠️ [LEAK_ANALYSIS] 总实例数: ${totalInstances}`);
    console.log(`⚠️ [LEAK_ANALYSIS] 总内存项数: ${totalMemoryItems}`);
    console.log(`⚠️ [LEAK_ANALYSIS] 预估内存占用: ${Math.round(totalInstances * 0.5)}MB`);
    console.log(`⚠️ [LEAK_ANALYSIS] 循环引用链: TipsJsBridge[${this.bridgeId}] <-> JsModule instances`);
    console.log(`⚠️ [LEAK_ANALYSIS] 关键字: ${this.leakMarker}, MEMORY_LEAK_MARKER`);
    console.log('⚠️ [LEAK_ANALYSIS] Web组件已销毁，但supportApiMap未清空，形成循环引用内存泄漏！');
    console.log('=== ⚠️ [LEAK_ANALYSIS] 分析结束 ===\n\n');
  }

  /**
   * 获取当前内存使用情况
   */
  getMemoryInfo(): MemoryInfo {
    const moduleCount = this.supportApiMap.length;
    let totalJsModules = 0;
    
    this.supportApiMap.forEach((moduleSet: Set<JsModule>) => {
      totalJsModules += moduleSet.size;
    });

    const memoryInfo: MemoryInfo = {
      supportApiMapSize: moduleCount,
      totalJsModules: totalJsModules,
      isDestroyed: this.isDestroyed,
      hasWebController: this.webController !== null
    };
    
    return memoryInfo;
  }
}