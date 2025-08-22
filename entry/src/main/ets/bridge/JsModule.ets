import { ITipsJsBridge, ModuleWorkParams } from './Types';

/**
 * JavaScript模块类
 * 持有bridge对象的引用，形成循环引用导致内存泄漏
 */
export class JsModule {
  private moduleName: string = '';
  private bridge: ITipsJsBridge | null = null; // 使用接口类型避免循环导入
  private moduleData: Map<string, Object> = new Map();

  constructor(name: string, bridge: ITipsJsBridge) {
    this.moduleName = name;
    this.bridge = bridge; // 持有bridge引用，形成循环引用
    console.log(`JsModule [${this.moduleName}] created with bridge reference`);
  }

  /**
   * 获取模块名称
   */
  getModuleName(): string {
    return this.moduleName;
  }

  /**
   * 获取桥接对象
   */
  getBridge(): ITipsJsBridge | null {
    return this.bridge;
  }

  /**
   * 设置模块数据
   */
  setData(key: string, value: Object): void {
    this.moduleData.set(key, value);
    console.log(`JsModule [${this.moduleName}] set data: ${key}`);
  }

  /**
   * 获取模块数据
   */
  getData(key: string): Object | undefined {
    return this.moduleData.get(key);
  }

  /**
   * 调用JavaScript方法
   */
  callJsFunction(functionName: string, params?: Object): void {
    console.log(`JsModule [${this.moduleName}] calling JS function: ${functionName}`);
    if (this.bridge) {
      // 通过bridge调用JavaScript
      this.bridge.callJsMethod(this.moduleName, functionName, params);
    }
  }

  /**
   * 模拟一些业务操作
   */
  doSomeWork(): void {
    console.log(`JsModule [${this.moduleName}] is doing some work...`);
    this.setData('lastWorkTime', new Date().toString());
    
    // 模拟调用JS方法
    const params: ModuleWorkParams = { 
      moduleName: this.moduleName, 
      timestamp: Date.now() 
    };
    this.callJsFunction('onModuleWork', params);
  }

  /**
   * 销毁方法 - 但在内存泄漏场景中不会被正确调用
   */
  destroy(): void {
    console.log(`JsModule [${this.moduleName}] destroying...`);
    this.moduleData.clear();
    // 注意：这里应该清除bridge引用，但在泄漏场景中不会被调用
    this.bridge = null;
  }
}