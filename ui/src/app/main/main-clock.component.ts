import { Router } from '@angular/router';
import { Component, ViewEncapsulation } from '@angular/core';
import { ApiService } from '../common';
import 'bootstrap/dist/css/bootstrap.css';
import { Observable } from "rxjs";

@Component({
  selector: MainClock.name.toLowerCase(),
  template: require("./main-clock.template.jade")
})
export class MainClock {
  constructor(public router: Router, public api: ApiService) {}

  datetime = {date: "", time: ""};

  ngOnInit() {
    Observable.timer(0, 100)
      .subscribe(_ => {
        let d = new Date();
        this.datetime.date = `${d.getMonth()+1}/${d.getDate()}`;
        // this.datetime.time = `${d.getHours()}:${d.getMinutes()}:${d.getSeconds()}`;
        let min = d.getMinutes().toString();
        this.datetime.time = `${d.getHours()}:${min.length==1?"0":""}${min}`;
      });
  }
}
