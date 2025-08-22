import { webview } from '@kit.ArkWeb';
import { TipsJsBridge } from '../bridge/TipsJsBridge';
import { JsModule } from '../bridge/JsModule';
import { JsBridgeObject, JsBridgeModule, MemoryInfo } from '../bridge/Types';

@Entry
@Component
struct Index {
  @State message: string = 'WebMemLeak演示应用';
  @State memoryInfo: string = '内存状态：未初始化';
  @State showWeb: boolean = false;
  
  private webController: webview.WebviewController = new webview.WebviewController();
  private jsBridge: TipsJsBridge | null = null;
  
  aboutToAppear(): void {
    console.log('Index页面即将出现');
  }
  
  aboutToDisappear(): void {
    console.log('Index页面即将消失');
    // 模拟内存泄漏：页面销毁时不清理bridge
    if (this.jsBridge) {
      this.jsBridge.simulateMemoryLeak();
      // 注意：这里故意不调用onDestroy()来模拟内存泄漏
      // this.jsBridge.onDestroy();
    }
  }

  /**
   * 创建Web组件和JsBridge
   */
  createWebComponent(): void {
    console.log('创建Web组件和JsBridge');
    
    // 创建TipsJsBridge实例
    this.jsBridge = new TipsJsBridge();
    this.jsBridge.onCreate();
    this.jsBridge.setWebController(this.webController);
    
    // 注册多个JS模块，形成循环引用
    const userModuleCallNative = (method: string, params: string) => {
      console.log(`Native方法被调用: ${method}, 参数: ${params}`);
    };
    const userModule = new JsBridgeModule(userModuleCallNative);
    this.jsBridge.registerModule('userModule', userModule);
    
    const deviceModuleCallNative = (method: string, params: string) => {
      console.log(`设备模块Native方法被调用: ${method}, 参数: ${params}`);
    };
    const deviceModule = new JsBridgeModule(deviceModuleCallNative);
    this.jsBridge.registerModule('deviceModule', deviceModule);
    
    const networkModuleCallNative = (method: string, params: string) => {
      console.log(`网络模块Native方法被调用: ${method}, 参数: ${params}`);
    };
    const networkModule = new JsBridgeModule(networkModuleCallNative);
    this.jsBridge.registerModule('networkModule', networkModule);
    
    this.showWeb = true;
    this.updateMemoryInfo();
    this.message = 'Web组件已创建，JsBridge已注入';
  }
  
  /**
   * 销毁Web组件（模拟内存泄漏）
   */
  destroyWebComponent(): void {
    console.log('销毁Web组件（模拟内存泄漏场景）');
    
    // 模拟内存泄漏：销毁Web组件但不清理supportApiMap
    this.showWeb = false;
    
    if (this.jsBridge) {
      // 故意不调用onDestroy()，模拟内存泄漏
      // this.jsBridge.onDestroy();
      
      // 显示泄漏信息
      this.jsBridge.simulateMemoryLeak();
      this.updateMemoryInfo();
    }
    
    this.message = 'Web组件已销毁，但存在内存泄漏！';
  }
  
  /**
   * 正确清理资源
   */
  cleanupProperly(): void {
    console.log('正确清理资源');
    
    if (this.jsBridge) {
      this.jsBridge.onDestroy();
      this.jsBridge = null;
    }
    
    this.showWeb = false;
    this.updateMemoryInfo();
    this.message = '资源已正确清理';
  }
  
  /**
   * 更新内存信息显示
   */
  updateMemoryInfo(): void {
    if (this.jsBridge) {
      const info: MemoryInfo = this.jsBridge.getMemoryInfo();
      this.memoryInfo = `模块数: ${info.supportApiMapSize}, JS模块总数: ${info.totalJsModules}, 已销毁: ${info.isDestroyed}`;
    } else {
      this.memoryInfo = '内存状态：Bridge已清理';
    }
  }
  
  /**
   * 模拟模块工作
   */
  simulateModuleWork(): void {
    if (this.jsBridge) {
      const modules = this.jsBridge.getAllModules();
      modules.forEach((jsModules: Object, moduleName: string) => {
        const moduleArray = jsModules as JsModule[];
        if (Array.isArray(moduleArray) && moduleArray.length > 0) {
          moduleArray[0].doSomeWork();
        }
      });
      this.updateMemoryInfo();
    }
  }

  build() {
    Column({ space: 20 }) {
      Text(this.message)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .textAlign(TextAlign.Center)
        .margin({ top: 20 })
      
      Text(this.memoryInfo)
        .fontSize(14)
        .fontColor(Color.Blue)
        .textAlign(TextAlign.Center)
      
      // 控制按钮
      Row({ space: 10 }) {
        Button('创建Web组件')
          .enabled(!this.showWeb)
          .onClick(() => {
            this.createWebComponent();
          })
        
        Button('销毁Web组件\n(内存泄漏)')
          .enabled(this.showWeb)
          .fontSize(12)
          .onClick(() => {
            this.destroyWebComponent();
          })
      }
      
      Row({ space: 10 }) {
        Button('模拟模块工作')
          .enabled(this.jsBridge !== null)
          .onClick(() => {
            this.simulateModuleWork();
          })
        
        Button('正确清理资源')
          .enabled(this.jsBridge !== null)
          .onClick(() => {
            this.cleanupProperly();
          })
      }
      
      Button('刷新内存信息')
        .onClick(() => {
          this.updateMemoryInfo();
        })
      
      // Web组件
      if (this.showWeb) {
        Web({ src: $rawfile('demo.html'), controller: this.webController })
          .width('90%')
          .height(200)
          .border({ width: 1, color: Color.Gray })
          .onPageEnd(() => {
            console.log('Web页面加载完成');
            // 通知TipsJsBridge Web组件已准备好
            if (this.jsBridge) {
              this.jsBridge.onWebComponentReady();
            }
          })
          .onErrorReceive((event) => {
            console.log('Web加载错误，使用本地HTML');
            // 即使加载错误，也通知Bridge准备完成
            if (this.jsBridge) {
              this.jsBridge.onWebComponentReady();
            }
          })
      }
      
      // 说明文字
      Text('内存泄漏演示说明：\n1. 点击"创建Web组件"创建TipsJsBridge和JsModule\n2. TipsJsBridge的supportApiMap持有JsModule\n3. JsModule又持有TipsJsBridge引用\n4. 点击"销毁Web组件"模拟内存泄漏场景\n5. Web组件销毁但supportApiMap未清空\n6. 形成循环引用导致内存泄漏')
        .fontSize(12)
        .fontColor(Color.Gray)
        .textAlign(TextAlign.Start)
        .margin({ top: 20 })
        .padding(10)
        .backgroundColor(Color.Yellow)
        .borderRadius(8)
    }
    .width('100%')
    .height('100%')
    .padding(20)
  }
}