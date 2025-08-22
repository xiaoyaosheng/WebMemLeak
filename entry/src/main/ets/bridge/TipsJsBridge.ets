import { IsBridge } from './IsBridge';
import { LifeCycle } from './LifeCycle';
import { JsModule } from './JsModule';
import { ITipsJsBridge, MemoryInfo } from './Types';
import { webview } from '@kit.ArkWeb';

/**
 * JavaScript桥接实现类
 * 实现IsBridge和LifeCycle接口
 * 与JsModule形成循环引用导致内存泄漏
 */
export class TipsJsBridge implements IsBridge, LifeCycle, ITipsJsBridge {
  // 核心问题：supportApiMap存放JsModule，而JsModule又持有bridge引用，形成循环引用
  private supportApiMap: Map<string, Set<JsModule>> = new Map();
  private webController: webview.WebviewController | null = null;
  private isDestroyed: boolean = false;

  constructor() {
    console.log('TipsJsBridge created');
  }

  /**
   * 设置Web控制器
   */
  setWebController(controller: webview.WebviewController): void {
    this.webController = controller;
    console.log('TipsJsBridge web controller set');
  }

  // ============ IsBridge接口实现 ============

  /**
   * 注册JS模块 - 这里会形成循环引用
   */
  registerModule(moduleName: string, module: Object): void {
    console.log(`TipsJsBridge registering module: ${moduleName}`);
    
    // 创建JsModule实例，传入this引用，形成循环引用
    const jsModule = new JsModule(moduleName, this);
    
    // 添加到supportApiMap中
    if (!this.supportApiMap.has(moduleName)) {
      this.supportApiMap.set(moduleName, new Set<JsModule>());
    }
    
    const moduleSet = this.supportApiMap.get(moduleName);
    if (moduleSet) {
      moduleSet.add(jsModule);
      console.log(`Module ${moduleName} added to supportApiMap. Current size: ${moduleSet.size}`);
    }

    // 模拟注册到Web组件
    if (this.webController) {
      this.webController.registerJavaScriptProxy(module, moduleName, ['callNative']);
    }
  }

  /**
   * 注销JS模块 - 在内存泄漏场景中不会被正确调用
   */
  unregisterModule(moduleName: string): void {
    console.log(`TipsJsBridge unregistering module: ${moduleName}`);
    
    const moduleSet = this.supportApiMap.get(moduleName);
    if (moduleSet) {
      // 应该正确销毁模块，但在泄漏场景中这个方法不会被调用
      moduleSet.forEach(module => {
        module.destroy();
      });
      moduleSet.clear();
      this.supportApiMap.delete(moduleName);
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
    this.supportApiMap.forEach((moduleSet, moduleName) => {
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
    
    // 正确的销毁应该清理所有模块
    // 但在内存泄漏场景中，Web组件销毁时这个方法不会被调用
    this.supportApiMap.forEach((moduleSet, moduleName) => {
      console.log(`Destroying modules for ${moduleName}, count: ${moduleSet.size}`);
      moduleSet.forEach(module => {
        module.destroy();
      });
      moduleSet.clear();
    });
    
    this.supportApiMap.clear();
    this.webController = null;
    console.log('TipsJsBridge destroyed completely');
  }

  // ============ 用于演示内存泄漏的方法 ============

  /**
   * 模拟内存泄漏场景：Web组件销毁但supportApiMap没有清空
   */
  simulateMemoryLeak(): void {
    console.log('=== 模拟内存泄漏场景 ===');
    console.log(`当前supportApiMap大小: ${this.supportApiMap.size}`);
    
    this.supportApiMap.forEach((moduleSet, moduleName) => {
      console.log(`模块 ${moduleName} 包含 ${moduleSet.size} 个JsModule实例`);
      moduleSet.forEach(module => {
        console.log(`  - JsModule ${module.getModuleName()} 仍持有bridge引用: ${module.getBridge() !== null}`);
      });
    });
    
    console.log('Web组件已销毁，但supportApiMap未清空，形成循环引用内存泄漏！');
  }

  /**
   * 获取当前内存使用情况
   */
  getMemoryInfo(): MemoryInfo {
    const moduleCount = this.supportApiMap.size;
    let totalJsModules = 0;
    
    this.supportApiMap.forEach(moduleSet => {
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