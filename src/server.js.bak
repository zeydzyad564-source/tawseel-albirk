import express from 'express'; import cors from 'cors'; import bcrypt from 'bcryptjs'; import crypto from 'crypto'; import jwt from 'jsonwebtoken'; import pg from 'pg'; import dotenv from 'dotenv'; dotenv.config();
const {Pool}=pg, pool=new Pool({connectionString:process.env.DATABASE_URL}); const app=express(); app.use(cors({origin:true,credentials:true})); app.use(express.json());
app.use(express.static('public'));
const PORT=Number(process.env.PORT||3000), CENTER={lat:18.2167,lng:41.5350}, RADIUS=18;
const q=(s,p)=>pool.query(s,p);
function token(u){return jwt.sign({sub:u.id,role:u.role,name:u.name,phone:u.phone},process.env.JWT_SECRET,{expiresIn:'30d'})}
function auth(req,res,next){try{let h=req.headers.authorization||''; if(!h.startsWith('Bearer ')) throw 0; req.user=jwt.verify(h.slice(7),process.env.JWT_SECRET); next()}catch{res.status(401).json({error:'يجب تسجيل الدخول'})}}
function role(...rs){return (req,res,next)=>rs.includes(req.user.role)?next():res.status(403).json({error:'ليس لديك صلاحية'})}
function km(a,b,c,d){const R=6371,x=(c-a)*Math.PI/180,y=(d-b)*Math.PI/180,z=Math.sin(x/2)**2+Math.cos(a*Math.PI/180)*Math.cos(c*Math.PI/180)*Math.sin(y/2)**2;return R*2*Math.atan2(Math.sqrt(z),Math.sqrt(1-z))}
function fee(d){if(d<=3)return 10;if(d<=5)return 13;if(d<=7)return 16;if(d<=10)return 20;if(d<=15)return 27;return 27+Math.ceil(d-15)*2}
app.get('/health',async(_req,res)=>{try{await q('select 1');res.json({ok:true,database:'connected'})}catch{res.status(503).json({ok:false,database:'disconnected'})}});
app.post('/api/auth/register',async(req,res)=>{try{let {name,phone,password}=req.body;if(!name||!phone||!password||password.length<6)return res.status(400).json({error:'الاسم والجوال وكلمة المرور مطلوبة'});if((await q('select id from users where phone=$1',[phone])).rowCount)return res.status(409).json({error:'يوجد حساب بهذا الرقم'});let u={id:crypto.randomUUID(),name:name.trim(),phone:phone.trim(),role:'customer'};await q('insert into users(id,name,phone,password_hash,role) values($1,$2,$3,$4,$5)',[u.id,u.name,u.phone,await bcrypt.hash(password,12),u.role]);res.status(201).json({user:u,token:token(u)})}catch(e){console.error(e);res.status(500).json({error:'حدث خطأ'})}});
app.post('/api/auth/login',async(req,res)=>{try{let r=await q('select * from users where phone=$1',[req.body.phone]);if(!r.rowCount||!(await bcrypt.compare(req.body.password||'',r.rows[0].password_hash)))return res.status(401).json({error:'بيانات الدخول غير صحيحة'});let x=r.rows[0],u={id:x.id,name:x.name,phone:x.phone,role:x.role};res.json({user:u,token:token(u)})}catch(e){res.status(500).json({error:'حدث خطأ'})}});
app.get('/api/auth/me',auth,async(req,res)=>{let r=await q('select id,name,phone,role from users where id=$1',[req.user.sub]);res.json({user:r.rows[0]})});
app.post('/api/drivers/apply',auth,async(req,res)=>{let {idNo,vehicle,area='البرك',iban}=req.body;if(!iban)return res.status(400).json({error:'IBAN مطلوب'});await q("update users set role='driver' where id=$1",[req.user.sub]);await q("insert into driver_profiles(user_id,id_no,vehicle,area,iban,status) values($1,$2,$3,$4,$5,'pending') on conflict(user_id) do update set id_no=$2,vehicle=$3,area=$4,iban=$5,status='pending'",[req.user.sub,idNo||null,vehicle||null,area,iban]);res.json({ok:true,status:'pending'})});
app.post('/api/orders',auth,role('customer','admin'),async(req,res)=>{let {serviceType,storeName,items,note,pickup,dropoff,offerPrice,paymentMethod='cash'}=req.body;if(!items||!pickup||!dropoff)return res.status(400).json({error:'بيانات الطلب والموقعين مطلوبة'});if(km(dropoff.lat,dropoff.lng,CENTER.lat,CENTER.lng)>RADIUS||km(pickup.lat,pickup.lng,CENTER.lat,CENTER.lng)>RADIUS)return res.status(400).json({error:'التوصيل متاح داخل البرك فقط'});let d=km(pickup.lat,pickup.lng,dropoff.lat,dropoff.lng),f=fee(d);let r=await q('insert into orders(customer_id,service_type,store_name,items,note,pickup_lat,pickup_lng,dropoff_lat,dropoff_lng,distance_km,delivery_fee,offer_price,payment_method) values($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13) returning *',[req.user.sub,serviceType||'أخرى',storeName||null,items,note||null,pickup.lat,pickup.lng,dropoff.lat,dropoff.lng,d.toFixed(2),f,Number(offerPrice)||f,paymentMethod]);res.status(201).json({order:r.rows[0]})});
app.get('/api/orders/:id/offers',auth,role('customer','admin'),async(req,res)=>{
  try{
    let o=await q(
      'select id,customer_id from orders where id=$1',
      [req.params.id]
    );

    if(!o.rowCount)
      return res.status(404).json({error:'الطلب غير موجود'});

    if(
      req.user.role==='customer' &&
      o.rows[0].customer_id!==req.user.sub
    )
      return res.status(403).json({error:'هذا ليس طلبك'});

    let r=await q(`
      select
        dof.id,
        dof.order_id,
        dof.driver_id,
        dof.price,
        dof.status,
        dof.created_at,
        u.name driver_name,
        u.phone driver_phone,
        dp.vehicle,
        dp.area
      from driver_offers dof
      join users u on u.id=dof.driver_id
      left join driver_profiles dp on dp.user_id=dof.driver_id
      where dof.order_id=$1
      order by dof.price asc,dof.created_at asc
    `,[req.params.id]);

    res.json({offers:r.rows});

  }catch(e){
    console.error(e);
    res.status(500).json({error:'حدث خطأ'});
  }
});
app.get('/api/orders',auth,async(req,res)=>{let r;if(req.user.role==='admin')r=await q('select o.*,u.name customer_name,u.phone customer_phone from orders o join users u on u.id=o.customer_id order by o.created_at desc');else if(req.user.role==='driver')r=await q("select o.*,u.name customer_name from orders o join users u on u.id=o.customer_id where o.status='pending_offers' or o.driver_id=$1 order by o.created_at desc",[req.user.sub]);else r=await q('select * from orders where customer_id=$1 order by created_at desc',[req.user.sub]);res.json({orders:r.rows})});
app.post('/api/orders/:id/offers',auth,role('driver'),async(req,res)=>{let p=Number(req.body.price);if(!Number.isFinite(p)||p<0)return res.status(400).json({error:'السعر غير صحيح'});let d=await q("select status from driver_profiles where user_id=$1",[req.user.sub]);if(!d.rowCount||d.rows[0].status!=='approved')return res.status(403).json({error:'المندوب غير معتمد'});let o=await q("select id from orders where id=$1 and status='pending_offers'",[req.params.id]);if(!o.rowCount)return res.status(409).json({error:'الطلب غير متاح'});try{let r=await q('insert into driver_offers(order_id,driver_id,price) values($1,$2,$3) returning *',[req.params.id,req.user.sub,p]);res.status(201).json({offer:r.rows[0]})}catch(e){res.status(e.code==='23505'?409:500).json({error:e.code==='23505'?'لديك عرض سابق لهذا الطلب':'حدث خطأ'})}});
app.post('/api/orders/:id/accept-offer/:offerId',auth,role('customer','admin'),async(req,res)=>{let c=await pool.connect();try{await c.query('begin');let o=(await c.query('select * from orders where id=$1 for update',[req.params.id])).rows[0];if(!o)return res.status(404).json({error:'الطلب غير موجود'});if(req.user.role==='customer'&&o.customer_id!==req.user.sub)return res.status(403).json({error:'هذا ليس طلبك'});if(o.status!=='pending_offers')return res.status(409).json({error:'الطلب لم يعد متاحاً'});let offer=(await c.query('select * from driver_offers where id=$1 and order_id=$2 for update',[req.params.offerId,req.params.id])).rows[0];if(!offer)return res.status(404).json({error:'العرض غير موجود'});let a=(await c.query("select count(*)::int c from orders where driver_id=$1 and status in ('accepted','in_delivery')",[offer.driver_id])).rows[0].c;if(a>=2){await c.query('rollback');return res.status(409).json({error:'المندوب لديه طلبان نشطان بالفعل'})}await c.query("update orders set driver_id=$1,status='accepted',offer_price=$2,updated_at=now() where id=$3",[offer.driver_id,offer.price,o.id]);await c.query("update driver_offers set status=case when id=$1 then 'accepted' else 'rejected' end where order_id=$2",[offer.id,o.id]);await c.query('commit');res.json({ok:true})}catch(e){await c.query('rollback');res.status(500).json({error:'تعذر قبول العرض'})}finally{c.release()}});
app.post('/api/orders/:id/status',auth,async(req,res)=>{let s=req.body.status;if(!['in_delivery','delivered','cancelled'].includes(s))return res.status(400).json({error:'حالة غير صحيحة'});let o=(await q('select * from orders where id=$1',[req.params.id])).rows[0];if(!o)return res.status(404).json({error:'الطلب غير موجود'});let ok=req.user.role==='admin'||(req.user.role==='driver'&&o.driver_id===req.user.sub)||(req.user.role==='customer'&&o.customer_id===req.user.sub&&s==='cancelled');if(!ok)return res.status(403).json({error:'لا تملك الصلاحية'});let r=await q('update orders set status=$1,updated_at=now() where id=$2 returning *',[s,o.id]);res.json({order:r.rows[0]})});
app.get('/api/admin/overview',auth,role('admin'),async(_req,res)=>{let [a,b,c,d,drivers]=await Promise.all([q('select count(*)::int c from orders'),q('select count(*)::int c from driver_profiles'),q("select count(*)::int c from orders where status='in_delivery'"),q("select count(*)::int c from orders where status='delivered'"),q('select u.id,u.name,u.phone,dp.vehicle,dp.area,dp.iban,dp.status from driver_profiles dp join users u on u.id=dp.user_id order by dp.created_at desc')]);res.json({stats:{orders:a.rows[0].c,drivers:b.rows[0].c,active:c.rows[0].c,done:d.rows[0].c},drivers:drivers.rows})});
app.listen(PORT,()=>console.log('Tawseel Al-Birk server on '+PORT));
