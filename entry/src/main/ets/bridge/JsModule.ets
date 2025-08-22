import { ITipsJsBridge, ModuleWorkParams } from './Types';

/**
 * JavaScript模块类
 * 持有bridge对象的引用，形成循环引用导致内存泄漏
 */
export class JsModule {
  private moduleName: string = '';
  private bridge: ITipsJsBridge | null = null;
  private moduleData: Map<string, Object> = new Map();
  private memoryHolders: Array<string> = []; // 大量内存占用者
  private creationTime: number = Date.now();
  private workCounter: number = 0;
  private uniqueId: string = ''; // 唯一标识，方便Profile识别
  private leakMarker: string = 'MEMORY_LEAK_MARKER'; // 泄漏标记

  constructor(name: string, bridge: ITipsJsBridge) {
    this.moduleName = name;
    this.bridge = bridge;
    this.uniqueId = `JsModule_${name}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    
    // 创建大量内存占用数据，让泄漏更明显
    for (let i = 0; i < 200; i++) {
      this.memoryHolders.push(`${this.leakMarker}_大容量数据块_${name}_${i}_${Math.random().toString(36).repeat(50)}`);
    }
    
    // 添加显著的标识信息
    this.moduleData.set('LEAK_IDENTIFIER', `${this.leakMarker}_${this.uniqueId}`);
    this.moduleData.set('CREATION_STACK', new Error().stack || 'Unknown');
    
    console.log(`⚠️ [LEAK_ANALYSIS] JsModule [${this.moduleName}] created with ID: ${this.uniqueId}`);
    console.log(`⚠️ [LEAK_ANALYSIS] Bridge reference: ${this.bridge !== null}`);
    console.log(`⚠️ [LEAK_ANALYSIS] Memory holders count: ${this.memoryHolders.length}`);
  }

  /**
   * 获取模块名称
   */
  getModuleName(): string {
    return this.moduleName;
  }

  /**
   * 获取唯一标识（用于Profile分析）
   */
  getUniqueId(): string {
    return this.uniqueId;
  }

  /**
   * 获取泄漏标记（用于Profile分析）
   */
  getLeakMarker(): string {
    return this.leakMarker;
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
    this.workCounter++;
    console.log(`⚠️ [LEAK_ANALYSIS] JsModule [${this.moduleName}] doing work #${this.workCounter}, ID: ${this.uniqueId}`);
    
    // 每次工作都添加更多内存占用（带有明显标识）
    for (let i = 0; i < 50; i++) {
      this.memoryHolders.push(`${this.leakMarker}_工作数据_${this.workCounter}_${i}_${this.uniqueId}_${Math.random().toString(36).repeat(30)}`);
    }
    
    // 添加更多有标识的数据
    this.setData(`${this.leakMarker}_lastWorkTime`, new Date().toString());
    this.setData(`${this.leakMarker}_workCounter`, this.workCounter);
    this.setData(`${this.leakMarker}_memoryHoldersCount`, this.memoryHolders.length);
    this.setData(`${this.leakMarker}_creationTime`, this.creationTime);
    this.setData(`${this.leakMarker}_bridgeRef`, this.bridge !== null ? 'ACTIVE' : 'NULL');
    
    // 模拟调用JS方法
    const params: ModuleWorkParams = { 
      moduleName: this.moduleName, 
      timestamp: Date.now() 
    };
    this.callJsFunction('onModuleWork', params);
    
    console.log(`⚠️ [LEAK_ANALYSIS] JsModule [${this.moduleName}] now holds ${this.memoryHolders.length} memory items with marker: ${this.leakMarker}`);
  }

  /**
   * 销毁方法 - 但在内存泄漏场景中不会被正确调用
   */
  destroy(): void {
    console.log(`JsModule [${this.moduleName}] destroying... releasing ${this.memoryHolders.length} memory items`);
    this.moduleData.clear();
    this.memoryHolders = []; // 清理大量内存数据
    // 注意：这里应该清除bridge引用，但在泄漏场景中不会被调用
    this.bridge = null;
    console.log(`JsModule [${this.moduleName}] destroyed completely`);
  }
}